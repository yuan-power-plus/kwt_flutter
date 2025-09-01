import '../models/models.dart';
import '../services/kwt_client.dart';
import '../utils/result.dart';
import 'repository_interfaces.dart';

/// 基于 KwtClient 的认证仓库实现
class KwtAuthRepository implements AuthRepository {
  const KwtAuthRepository(this._client);
  
  final KwtClient _client;

  @override
  Future<Result<List<int>>> getCaptcha() async {
    return resultOf(() async {
      final captcha = await _client.fetchCaptcha();
      return captcha.toList();
    });
  }

  @override
  Future<Result<bool>> login({
    required String userAccount,
    required String userPassword,
    required String verifyCode,
  }) async {
    return resultOf(() => _client.login(
      userAccount: userAccount,
      userPassword: userPassword,
      verifyCode: verifyCode,
    ));
  }

  @override
  Future<Result<void>> logout() async {
    return resultOf(() => _client.logout());
  }

  @override
  Future<Result<Map<String, String>>> getProfileInfo() async {
    return resultOf(() => _client.fetchProfileInfo());
  }
}

/// 基于 KwtClient 的课表仓库实现
class KwtTimetableRepository implements TimetableRepository {
  const KwtTimetableRepository(this._client);
  
  final KwtClient _client;

  @override
  Future<Result<List<TimetableEntry>>> getPersonalTimetable({
    required String date,
    required String timeMode,
    required String termId,
    bool showWeekend = false,
  }) async {
    return resultOf(() => _client.fetchPersonalTimetableStructured(
      date: date,
      timeMode: timeMode,
      termId: termId,
      showWeekend: showWeekend,
    ));
  }

  @override
  Future<Result<List<TimetableEntry>>> getClassTimetable({
    required String term,
    required String timeMode,
    String department = '',
    String grade = '',
    String major = '',
    String classId = '',
    String className = '',
    String weekStart = '',
    String weekEnd = '',
    String weekdayStart = '',
    String weekdayEnd = '',
    String sectionStart = '',
    String sectionEnd = '',
  }) async {
    return resultOf(() => _client.fetchClassTimetableStructured(
      term: term,
      timeMode: timeMode,
      department: department,
      grade: grade,
      major: major,
      classId: classId,
      className: className,
      weekStart: weekStart,
      weekEnd: weekEnd,
      weekdayStart: weekdayStart,
      weekdayEnd: weekdayEnd,
      sectionStart: sectionStart,
      sectionEnd: sectionEnd,
    ));
  }

  @override
  Future<Result<List<Map<String, String>>>> searchClasses({
    required String keyword,
    int maxRow = 10,
  }) async {
    return resultOf(() => _client.searchClasses(
      keyword: keyword,
      maxRow: maxRow,
    ));
  }
}

/// 基于 KwtClient 的成绩仓库实现
class KwtGradeRepository implements GradeRepository {
  const KwtGradeRepository(this._client);
  
  final KwtClient _client;

  @override
  Future<Result<List<GradeEntry>>> getGrades({
    required String term,
    String courseProperty = '',
    String courseAttr = '',
    String courseName = '',
    String display = 'all',
    String mold = '',
  }) async {
    return resultOf(() => _client.fetchGradesStructured(
      term: term,
      courseProperty: courseProperty,
      courseAttr: courseAttr,
      courseName: courseName,
      display: display,
      mold: mold,
    ));
  }

  @override
  Future<Result<List<ExamLevelEntry>>> getExamLevel() async {
    return resultOf(() => _client.fetchExamLevel());
  }
}

/// 基于 KwtClient 的系统信息仓库实现
class KwtSystemRepository implements SystemRepository {
  const KwtSystemRepository(this._client);
  
  final KwtClient _client;

  @override
  Future<Result<List<String>>> getTermOptions() async {
    return resultOf(() => _client.fetchTermOptions());
  }
}