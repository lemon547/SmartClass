import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

/// 本地附件目录：Documents/{root}/{classId}/{ownerId}/
abstract final class LocalFileArchive {
  static const _uuid = Uuid();

  static const lessonRoot = 'lesson_archives';
  static const examRoot = 'exam_archives';
  static const workLogRoot = 'work_log_archives';
  static const titleMaterialRoot = 'title_materials';
  static const leaveProofRoot = 'leave_proofs';
  /// 老师个人附件（不绑班级）
  static const teacherOwner = 'teacher';

  static Future<Directory> ownerDir({
    required String root,
    required String classId,
    required String ownerId,
  }) async {
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(docs.path, root, classId, ownerId));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  static Future<String> absolutePath({
    required String root,
    required String classId,
    required String ownerId,
    required String storedName,
  }) async {
    final dir = await ownerDir(root: root, classId: classId, ownerId: ownerId);
    return p.join(dir.path, storedName);
  }

  static Future<({String storedName, int sizeBytes})> importFile({
    required String root,
    required String classId,
    required String ownerId,
    required String sourcePath,
    required String originalName,
  }) async {
    final dir = await ownerDir(root: root, classId: classId, ownerId: ownerId);
    final ext = p.extension(originalName);
    final stored = '${_uuid.v4()}$ext';
    final dest = File(p.join(dir.path, stored));
    await File(sourcePath).copy(dest.path);
    return (storedName: stored, sizeBytes: await dest.length());
  }

  static Future<void> deleteFile({
    required String root,
    required String classId,
    required String ownerId,
    required String storedName,
  }) async {
    final path = await absolutePath(
      root: root,
      classId: classId,
      ownerId: ownerId,
      storedName: storedName,
    );
    final f = File(path);
    if (await f.exists()) await f.delete();
  }

  static Future<void> deleteOwnerDir({
    required String root,
    required String classId,
    required String ownerId,
  }) async {
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(docs.path, root, classId, ownerId));
    if (await dir.exists()) await dir.delete(recursive: true);
  }

  static Future<void> deleteClassDir({
    required String root,
    required String classId,
  }) async {
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(docs.path, root, classId));
    if (await dir.exists()) await dir.delete(recursive: true);
  }
}

/// 兼容旧调用名
abstract final class LessonArchiveStore {
  static Future<Directory> unitDir({
    required String classId,
    required String unitId,
  }) =>
      LocalFileArchive.ownerDir(
        root: LocalFileArchive.lessonRoot,
        classId: classId,
        ownerId: unitId,
      );

  static Future<String> absolutePath({
    required String classId,
    required String unitId,
    required String storedName,
  }) =>
      LocalFileArchive.absolutePath(
        root: LocalFileArchive.lessonRoot,
        classId: classId,
        ownerId: unitId,
        storedName: storedName,
      );

  static Future<({String storedName, int sizeBytes})> importFile({
    required String classId,
    required String unitId,
    required String sourcePath,
    required String originalName,
  }) =>
      LocalFileArchive.importFile(
        root: LocalFileArchive.lessonRoot,
        classId: classId,
        ownerId: unitId,
        sourcePath: sourcePath,
        originalName: originalName,
      );

  static Future<void> deleteFile({
    required String classId,
    required String unitId,
    required String storedName,
  }) =>
      LocalFileArchive.deleteFile(
        root: LocalFileArchive.lessonRoot,
        classId: classId,
        ownerId: unitId,
        storedName: storedName,
      );

  static Future<void> deleteUnitDir({
    required String classId,
    required String unitId,
  }) =>
      LocalFileArchive.deleteOwnerDir(
        root: LocalFileArchive.lessonRoot,
        classId: classId,
        ownerId: unitId,
      );

  static Future<void> deleteClassDir(String classId) =>
      LocalFileArchive.deleteClassDir(
        root: LocalFileArchive.lessonRoot,
        classId: classId,
      );
}
