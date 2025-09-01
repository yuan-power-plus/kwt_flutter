import '../models/models.dart';
import '../utils/result.dart';

/// 认证仓库接口
abstract class AuthRepository {
  /// 获取验证码
  Future<Result<List<int>>> getCaptcha();
  
  /// 登录
  Future<Result<bool>> login({
    required String userAccount,
    required String userPassword,
    required String verifyCode,
  });
  
  /// 退出登录
  Future<Result<void>> logout();
  
  /// 获取用户信息
  Future<Result<Map<String, String>>> getProfileInfo();
}

/// 课表仓库接口
abstract class TimetableRepository {
  /// 获取个人课表
  Future<Result<List<TimetableEntry>>> getPersonalTimetable({
    required String date,
    required String timeMode,
    required String termId,
    bool showWeekend = false,
  });
  
  /// 获取班级课表
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
  });
  
  /// 搜索班级
  Future<Result<List<Map<String, String>>>> searchClasses({
    required String keyword,
    int maxRow = 10,
  });
}

/// 成绩仓库接口
abstract class GradeRepository {
  /// 获取课程成绩
  Future<Result<List<GradeEntry>>> getGrades({
    required String term,
    String courseProperty = '',
    String courseAttr = '',
    String courseName = '',
    String display = 'all',
    String mold = '',
  });
  
  /// 获取等级考试成绩
  Future<Result<List<ExamLevelEntry>>> getExamLevel();
}

/// 系统信息仓库接口
abstract class SystemRepository {
  /// 获取学期选项
  Future<Result<List<String>>> getTermOptions();
}