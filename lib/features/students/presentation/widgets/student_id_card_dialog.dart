/// Student ID card view and printable layout.
library;

import 'package:flutter/material.dart';
import '../../../../app/theme/app_theme.dart';
import '../../../../core/printing/pdf_document_service.dart';
import '../../../../shared/widgets/pdf_print_preview_dialog.dart';
import '../../domain/entities/student_entities.dart';

class StudentIdCardDialog extends StatelessWidget {

  const StudentIdCardDialog({
    super.key,
    required this.student,
    required this.batchName,
    this.academyName = 'ClassKhata Academy',
    this.academyPhone,
    this.academyAddress,
  });
  final Student student;
  final String batchName;
  final String academyName;
  final String? academyPhone;
  final String? academyAddress;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 380),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: const [
              BoxShadow(color: Colors.black26, blurRadius: 10, spreadRadius: 2),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Card Header
              Container(
                padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
                decoration: const BoxDecoration(
                  color: AppColors.heading,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.school, color: Colors.white, size: 28),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            academyName,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          const Text(
                            'STUDENT IDENTITY CARD',
                            style: TextStyle(
                              color: AppColors.accentLight,
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 1.2,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              // Card Body
              Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: AppColors.inputFill,
                        shape: BoxShape.circle,
                        border: Border.all(color: AppColors.accent, width: 2),
                      ),
                      child: const Icon(Icons.person, size: 48, color: AppColors.accent),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      student.name,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.heading,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      student.rollNumber,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.accent,
                        letterSpacing: 1.5,
                      ),
                    ),
                    const Divider(height: 28),
                    _infoRow('Batch', batchName),
                    const SizedBox(height: 8),
                    _infoRow('Guardian Phone', student.guardianPhone),
                    if (student.phone != null) ...[
                      const SizedBox(height: 8),
                      _infoRow('Contact', student.phone!),
                    ],
                    const SizedBox(height: 8),
                    _infoRow(
                      'Issued',
                      '${student.joiningDate.day}/${student.joiningDate.month}/${student.joiningDate.year}',
                    ),
                  ],
                ),
              ),
              // Card Footer Actions
              Padding(
                padding: const EdgeInsets.only(bottom: 16, left: 20, right: 20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Close'),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.print, size: 16),
                      label: const Text('Print Preview'),
                      onPressed: () {
                        PdfPrintPreviewDialog.show(
                          context,
                          title: 'Student ID Card - ${student.name}',
                          pdfFileName: 'id_card_${student.rollNumber}.pdf',
                          buildPdf: (format) => PdfDocumentService.generateStudentIdCardPdf(
                            student: student,
                            academyName: academyName,
                            batchName: batchName,
                            academyPhone: academyPhone,
                            academyAddress: academyAddress,
                            format: format,
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(color: AppColors.textMuted, fontSize: 13)),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
      ],
    );
  }
}
