import 'package:flutter_test/flutter_test.dart';
import 'package:drift/native.dart';
import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:classkhata/core/database/app_database.dart';
import 'package:classkhata/features/inventory/data/datasources/inventory_dao.dart';

void main() {
  late AppDatabase db;
  late InventoryDao inventoryDao;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    inventoryDao = InventoryDao(db);

    // Seed User
    await db.into(db.usersTable).insert(
          UsersTableCompanion.insert(
            name: 'System Administrator',
            email: 'admin@classkhata.local',
            passwordHash: 'hashed_pw',
            role: 'admin',
          ),
        );

    // Seed Category
    await db.into(db.inventoryCategoriesTable).insert(
          InventoryCategoriesTableCompanion.insert(
            name: 'Stationery',
            createdBy: const Value(1),
          ),
        );
  });

  tearDown(() async {
    await db.close();
  });

  group('Inventory Database Transactions & Stock Rules', () {
    test('Maintains stock balance after IN and OUT movements and updates cached quantityOnHand', () async {
      // 1. Create item with initial quantity 10
      final itemId = await db.into(db.inventoryItemsTable).insert(
            InventoryItemsTableCompanion.insert(
              categoryId: 1,
              name: 'Oxford Notebooks',
              unit: const Value('pcs'),
              quantityOnHand: const Value(10),
              unitCostPaisa: const Value(5000), // 50 PKR
              reorderLevel: const Value(5),
              createdBy: const Value(1),
            ),
          );

      // 2. Record Stock IN movement (+15)
      await inventoryDao.recordMovementTransaction(
        itemId: itemId,
        movementType: 'in',
        quantity: 15,
        unitCostPaisa: 5000,
        reason: 'Received shipment',
        createdBy: 1,
      );

      var item = await inventoryDao.getItemById(itemId);
      expect(item.quantityOnHand, 25);

      // 3. Record Stock OUT movement (-8)
      await inventoryDao.recordMovementTransaction(
        itemId: itemId,
        movementType: 'out',
        quantity: 8,
        unitCostPaisa: 5000,
        reason: 'Issued to Exam Dept',
        createdBy: 1,
      );

      item = await inventoryDao.getItemById(itemId);
      expect(item.quantityOnHand, 17);

      // Verify movement records
      final movements = await inventoryDao.getMovements(itemId: itemId);
      expect(movements.length, 2);
    });

    test('Prevents negative stock on OUT movements when allowNegativeStock is false', () async {
      final itemId = await db.into(db.inventoryItemsTable).insert(
            InventoryItemsTableCompanion.insert(
              categoryId: 1,
              name: 'Ballpoint Pens',
              quantityOnHand: const Value(5),
              unitCostPaisa: const Value(2000),
              createdBy: const Value(1),
            ),
          );

      // Attempting to issue 10 units when only 5 are available should throw
      expect(
        () async => await inventoryDao.recordMovementTransaction(
          itemId: itemId,
          movementType: 'out',
          quantity: 10,
          unitCostPaisa: 2000,
          reason: 'Excess issue test',
          createdBy: 1,
          allowNegativeStock: false,
        ),
        throwsA(isA<Exception>()),
      );

      // On-hand balance remains intact
      final item = await inventoryDao.getItemById(itemId);
      expect(item.quantityOnHand, 5);
    });

    test('Purchase transaction updates stock, supplier ledger, and cash book atomically', () async {
      // 1. Create Supplier
      final supplierId = await db.into(db.suppliersTable).insert(
            SuppliersTableCompanion.insert(
              name: 'National Stationers',
              openingBalancePaisa: const Value(100000), // 1,000 PKR opening payable
              currentBalancePaisa: const Value(100000),
              createdBy: const Value(1),
            ),
          );

      // 2. Create Items
      final item1Id = await db.into(db.inventoryItemsTable).insert(
            InventoryItemsTableCompanion.insert(
              categoryId: 1,
              name: 'Whiteboard Marker Black',
              quantityOnHand: const Value(5),
              unitCostPaisa: const Value(8000),
              createdBy: const Value(1),
            ),
          );
      final item2Id = await db.into(db.inventoryItemsTable).insert(
            InventoryItemsTableCompanion.insert(
              categoryId: 1,
              name: 'Whiteboard Marker Blue',
              quantityOnHand: const Value(5),
              unitCostPaisa: const Value(8000),
              createdBy: const Value(1),
            ),
          );

      // 3. Record multi-item purchase: 10x Item1 @ 80 PKR, 10x Item2 @ 80 PKR -> Total 1,600 PKR (160,000 paisa)
      // Paid 1,000 PKR (100,000 paisa) in Cash, remaining 600 PKR on credit
      await inventoryDao.recordPurchaseTransaction(
        purchaseNumber: 'PUR-2026-001',
        supplierId: supplierId,
        items: [
          (itemId: item1Id, quantity: 10, unitCostPaisa: 8000),
          (itemId: item2Id, quantity: 10, unitCostPaisa: 8000),
        ],
        paidAmountPaisa: 100000,
        paymentMode: 'cash',
        invoiceNumber: 'INV-9988',
        createdBy: 1,
      );

      // Verify stock in on both items
      final it1 = await inventoryDao.getItemById(item1Id);
      final it2 = await inventoryDao.getItemById(item2Id);
      expect(it1.quantityOnHand, 15);
      expect(it2.quantityOnHand, 15);

      // Verify supplier ledger: purchase entry (+160,000 paisa) and payment entry (100,000 paisa)
      final ledger = await inventoryDao.getSupplierLedger(supplierId);
      expect(ledger.length, 2);
      expect(ledger[0].transactionType, 'purchase');
      expect(ledger[0].amountPaisa, 160000);
      expect(ledger[1].transactionType, 'payment');
      expect(ledger[1].amountPaisa, 100000);

      // Supplier current balance should be opening (100,000) + net unpaid (60,000) = 160,000 paisa
      final supplier = await inventoryDao.getSupplierById(supplierId);
      expect(supplier.currentBalancePaisa, 160000);

      // Cash book should have 1 outflow entry for the 1,000 PKR paid
      final cashBookEntries = await (db.select(db.cashBookEntriesTable)
            ..where((t) => t.category.equals('inventory')))
          .get();
      expect(cashBookEntries.length, 1);
      expect(cashBookEntries.first.entryType, 'outflow');
      expect(cashBookEntries.first.amountPaisa, 100000);
    });

    test('Item issuance linked to Fee Voucher updates student fee voucher balance atomically', () async {
      // 1. Seed Academic session, course, batch, student
      final sessionId = await db.into(db.academicSessionsTable).insert(
            AcademicSessionsTableCompanion.insert(
              name: '2026-2027',
              startDate: DateTime(2026, 1, 1),
              endDate: DateTime(2026, 12, 31),
              createdBy: const Value(1),
            ),
          );
      final courseId = await db.into(db.coursesTable).insert(
            CoursesTableCompanion.insert(
              name: 'Matric Science',
              code: const Value('MAT-SCI'),
              createdBy: const Value(1),
            ),
          );
      final batchId = await db.into(db.batchesTable).insert(
            BatchesTableCompanion.insert(
              sessionId: sessionId,
              courseId: courseId,
              name: 'Class 9-A',
              monthlyFeePaisa: const Value(500000), // 5,000 PKR
              dueDay: const Value(10),
              createdBy: const Value(1),
            ),
          );
      final studentId = await db.into(db.studentsTable).insert(
            StudentsTableCompanion.insert(
              rollNumber: 'STD-0001',
              name: 'Ali Raza',
              guardianPhone: '03001234567',
              batchId: batchId,
              joiningDate: Value(DateTime(2026, 1, 15)),
              createdBy: const Value(1),
            ),
          );

      // 2. Create Fee Voucher (Total Due: 5,000 PKR = 500,000 paisa)
      final voucherId = await db.into(db.feeVouchersTable).insert(
            FeeVouchersTableCompanion.insert(
              voucherNumber: 'VCH-202610-0001',
              studentId: studentId,
              batchId: batchId,
              monthYear: '2026-10',
              issueDate: DateTime(2026, 10, 1),
              dueDate: DateTime(2026, 10, 10),
              baseAmountPaisa: const Value(500000),
              totalDuePaisa: const Value(500000),
              createdBy: const Value(1),
            ),
          );

      // 3. Create Inventory Item
      final itemId = await db.into(db.inventoryItemsTable).insert(
            InventoryItemsTableCompanion.insert(
              categoryId: 1,
              name: 'Science Practical Syllabus Book',
              quantityOnHand: const Value(20),
              unitCostPaisa: const Value(60000), // 600 PKR
              sellingPricePaisa: const Value(80000), // 800 PKR
              createdBy: const Value(1),
            ),
          );

      // 4. Issue 2 books to student and link to fee voucher @ 800 PKR each (Total charge: 1,600 PKR = 160,000 paisa)
      await inventoryDao.issueItemTransaction(
        itemId: itemId,
        quantity: 2,
        unitPricePaisa: 80000,
        recipientType: 'student',
        studentId: studentId,
        feeVoucherId: voucherId,
        reason: 'Issued Practical Journal',
        createdBy: 1,
      );

      // Item quantity on hand reduced by 2
      final item = await inventoryDao.getItemById(itemId);
      expect(item.quantityOnHand, 18);

      // Fee voucher total due should be updated: 500,000 + 160,000 = 660,000 paisa (6,600 PKR)
      final updatedVoucher = await (db.select(db.feeVouchersTable)..where((t) => t.id.equals(voucherId))).getSingle();
      expect(updatedVoucher.baseAmountPaisa, 660000);
      expect(updatedVoucher.totalDuePaisa, 660000);
    });

    test('Stock take reconciliation updates on-hand balance and records adjustment movements', () async {
      final itemId = await db.into(db.inventoryItemsTable).insert(
            InventoryItemsTableCompanion.insert(
              categoryId: 1,
              name: 'Lab Test Tubes (Pack)',
              quantityOnHand: const Value(30),
              unitCostPaisa: const Value(5000), // 50 PKR
              createdBy: const Value(1),
            ),
          );

      // Reconcile with physical count of 28 (discrepancy of -2)
      final result = await inventoryDao.reconcileStockTransaction(
        itemId: itemId,
        actualQuantity: 28,
        reason: '2 broken during handling',
        reconciledBy: 1,
      );

      expect(result.requiresApproval, false);
      expect(result.stockTake, isNotNull);
      expect(result.stockTake!.discrepancy, -2);

      // On-hand balance adjusted
      final item = await inventoryDao.getItemById(itemId);
      expect(item.quantityOnHand, 28);

      // Adjustment movement recorded
      final movements = await (db.select(db.inventoryMovementsTable)
            ..where((t) => t.itemId.equals(itemId) & t.movementType.equals('adjustment')))
          .get();
      expect(movements.length, 1);
      expect(movements.first.quantity, 2);
    });
  });
}
