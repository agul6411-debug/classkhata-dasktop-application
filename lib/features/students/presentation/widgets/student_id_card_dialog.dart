/// Student ID card view and printable layout with actual student photo and father details.
library;

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';


import '../../domain/entities/student_entities.dart';
import '../providers/student_providers.dart';

class StudentIdCardDialog extends ConsumerWidget {
  const StudentIdCardDialog({
    super.key,
    required this.student,
    required this.batchName,
    this.academyName = 'School Name',
    this.academyPhone,
    this.academyAddress,
  });

  final Student student;
  final String batchName;
  final String academyName;
  final String? academyPhone;
  final String? academyAddress;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(studentProfileProvider(student.id));
    final profile = profileAsync.valueOrNull;

    return Dialog(
      backgroundColor: Colors.transparent,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 380),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: const [
              BoxShadow(color: Colors.black26, blurRadius: 16, spreadRadius: 2),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Card Header
              Container(
                padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
                decoration: const BoxDecoration(
                  color: Color(0xFF1E3A8A), // Royal navy blue
                  borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
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
                            overflow: TextOverflow.ellipsis,
                          ),
                          const Text(
                            'STUDENT IDENTITY CARD',
                            style: TextStyle(
                              color: Colors.white70,
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
                padding: const EdgeInsets.all(22),
                child: Column(
                  children: [
                    // Student Photo
                    CircleAvatar(
                      radius: 42,
                      backgroundColor: const Color(0xFFF1F5F9),
                      backgroundImage: profile?.photoPath != null && File(profile!.photoPath!).existsSync()
                          ? FileImage(File(profile.photoPath!))
                          : null,
                      child: profile?.photoPath == null || !File(profile!.photoPath!).existsSync()
                          ? const Icon(Icons.person, size: 48, color: Color(0xFF1E3A8A))
                          : null,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      student.name,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        student.rollNumber,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF1E3A8A),
                          letterSpacing: 1.2,
                        ),
                      ),
                    ),
                    const Divider(height: 24, color: Color(0xFFE2E8F0)),
                    if (profile?.fatherName != null && profile!.fatherName!.isNotEmpty) ...[
                      _infoRow('Father Name', profile.fatherName!),
                      const SizedBox(height: 6),
                    ],
                    _infoRow('Class / Section', batchName),
                    const SizedBox(height: 6),
                    _infoRow('Guardian Phone', student.guardianPhone),
                    if (student.phone != null && student.phone!.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      _infoRow('Contact Phone', student.phone!),
                    ],
                    const SizedBox(height: 6),
                    _infoRow(
                      'Issue Date',
                      '${student.joiningDate.day}/${student.joiningDate.month}/${student.joiningDate.year}',
                    ),
                    if (academyPhone != null && academyPhone!.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      _infoRow('School Tel', academyPhone!),
                    ],
                  ],
                ),
              ),

              // Card Footer Actions
              Container(
                padding: const EdgeInsets.all(16),
                decoration: const BoxDecoration(
                  color: Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.vertical(bottom: Radius.circular(16)),
                ),
                child: SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Close'),
                  ),
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
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
        ),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.right,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Color(0xFF1E293B),
            ),
          ),
        ),
      ],
    );
  }
}
