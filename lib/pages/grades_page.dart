// 课程成绩页面：支持按学期查询、关键词搜索与统计展示
// 主要功能：
// 1) 选择学期并从后端加载成绩数据
// 2) 实时搜索课程名称/代码
// 3) 统计结果数量与平均分，并支持查看单条成绩详情
import 'package:flutter/material.dart';
import 'package:kwt_flutter/models/models.dart';
import 'package:kwt_flutter/services/kwt_client.dart';

/// 成绩列表页入口组件
///
/// 通过注入的 [KwtClient] 从后端获取成绩数据，并在页面中提供搜索与统计能力。
class GradesPage extends StatefulWidget {
  const GradesPage({super.key, required this.client});
  final KwtClient client;

  @override
  State<GradesPage> createState() => _GradesPageState();
}

/// 成绩页状态：承载查询条件、加载状态、错误信息与数据集
class _GradesPageState extends State<GradesPage> {
  final _termCtrl = TextEditingController();
  List<String> _termOptions = const [];
  bool _busy = false;
  String? _error;
  List<GradeEntry> _grades = const [];
  List<GradeEntry> _filteredGrades = const [];
  final TextEditingController _searchController = TextEditingController();
  

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_filterData);
    _init();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _termCtrl.dispose();
    super.dispose();
  }

  /// 触发筛选流程（委托给 [_applyFilters]），用于响应输入框变更
  void _filterData() {
    _applyFilters();
  }

  /// 根据当前搜索关键词对 [_grades] 进行过滤
  ///
  /// - 搜索范围：课程名称、课程代码（大小写不敏感）
  void _applyFilters() {
    final query = _searchController.text.toLowerCase();
    
    setState(() {
      _filteredGrades = _grades.where((grade) {
        // 搜索过滤
        final matchesSearch = query.isEmpty || 
            grade.courseName.toLowerCase().contains(query) ||
            grade.courseCode.toLowerCase().contains(query);
        return matchesSearch;
      }).toList();
    });
  }

  /// 根据当前选择的学期从后端加载成绩数据
  ///
  /// 若选择“全部学期”，将不携带学期参数，请求返回所有成绩。
  Future<void> _load() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final picked = _termCtrl.text.trim();
      final termParam = picked == '全部学期' ? '' : picked;
      final data = await widget.client.fetchGradesStructured(term: termParam);
      setState(() {
        _grades = data;
        _filteredGrades = data;
      });
    } catch (e) {
      setState(() => _error = '加载失败: $e');
    } finally {
      setState(() => _busy = false);
    }
  }

  /// 初始化学期选项并设置默认选中项（通常为最新学期）
  Future<void> _init() async {
    try {
      final terms = await widget.client.fetchTermOptions();
      _termOptions = ['全部学期', ...terms];
      if (_termCtrl.text.isEmpty && terms.isNotEmpty) {
        _termCtrl.text = terms.first; // 默认最新学期
      }
    } catch (_) {}
    setState(() {});
  }

  @override
  /// 页面主构建函数：包含查询条件区、搜索筛选区、统计信息区与成绩表格
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('课程成绩', style: TextStyle(color: Colors.black, fontWeight: FontWeight.w600)),
        backgroundColor: Colors.white,
        elevation: 0,
        automaticallyImplyLeading: true,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: Column(
        children: [
          // 查询条件区域
          Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.school, color: Colors.blue[600], size: 20),
                    const SizedBox(width: 8),
                    Text(
                      '查询条件',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey[800],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                child: _termOptions.isEmpty
                          ? TextField(
                              controller: _termCtrl,
                              decoration: InputDecoration(
                                labelText: '学年学期',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                filled: true,
                                fillColor: Colors.grey[50],
                                prefixIcon: Icon(Icons.calendar_today, color: Colors.grey[600]),
                              ),
                            )
                    : DropdownButtonFormField<String>(
                        value: _termOptions.contains(_termCtrl.text) ? _termCtrl.text : null,
                        items: _termOptions.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                        onChanged: (v) => setState(() => _termCtrl.text = v ?? _termCtrl.text),
                              decoration: InputDecoration(
                                labelText: '学年学期',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                filled: true,
                                fillColor: Colors.grey[50],
                                prefixIcon: Icon(Icons.calendar_today, color: Colors.grey[600]),
                              ),
                            ),
                    ),
                    const SizedBox(width: 16),
                    ElevatedButton(
                      onPressed: _busy ? null : _load,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue[600],
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text('查询', style: TextStyle(fontWeight: FontWeight.w600)),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // 搜索区域
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '搜索',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[800],
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.grey[50],
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey[200]!),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.search, color: Colors.grey[600], size: 20),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextField(
                                controller: _searchController,
                                decoration: const InputDecoration(
                                  hintText: '搜索课程名称...',
                                  border: InputBorder.none,
                                  hintStyle: TextStyle(color: Colors.grey),
                                ),
                              ),
                            ),
                            if (_searchController.text.isNotEmpty)
                              IconButton(
                                onPressed: () {
                                  _searchController.clear();
                                  _filterData();
                                },
                                icon: Icon(Icons.clear, color: Colors.grey[600], size: 18),
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // 统计信息
          if (_filteredGrades.isNotEmpty)
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.green[50],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.green[200]!),
              ),
              child: Row(
                children: [
                  Icon(Icons.analytics, color: Colors.green[700], size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      '共找到 ${_filteredGrades.length} 门课程',
                      style: TextStyle(
                        color: Colors.green[700],
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Text(
                    '平均分: ${_calculateAverageScore()}',
                    style: TextStyle(
                      color: Colors.green[700],
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),

          if (_error != null)
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red[200]!),
              ),
              child: Row(
                children: [
                  Icon(Icons.error_outline, color: Colors.red[600], size: 20),
              const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _error!,
                      style: TextStyle(color: Colors.red[600]),
                    ),
                  ),
                ],
              ),
            ),

          Expanded(
            child: _busy
                ? const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 16),
                        Text('加载中...', style: TextStyle(color: Colors.grey)),
                      ],
                    ),
                  )
                : _filteredGrades.isEmpty
                    ? _buildEmptyState()
                    : _buildGradesTable(),
          ),
        ],
      ),
    );
  }

  /// 空数据占位视图：根据是否处于搜索态展示不同提示
  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.search_off,
            size: 64,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            _searchController.text.isEmpty ? '暂无成绩数据' : '未找到相关课程',
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
          if (_searchController.text.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              '尝试使用其他关键词搜索',
              style: TextStyle(
                color: Colors.grey[500],
                fontSize: 14,
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// 成绩表格：表头 + 列表行 + 点击查看详情
  Widget _buildGradesTable() {
    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // 表头
          Container(
            decoration: BoxDecoration(
              color: Colors.blue[50],
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  flex: 1, // 序号更小
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    child: Text(
                      '序号',
                      style: TextStyle(
                        color: Colors.blue[700],
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
                Expanded(
                  flex: 2, // 课程名称更小
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      border: Border(
                        left: BorderSide(color: Colors.blue[200]!),
                      ),
                    ),
                    child: Text(
                      '课程名称',
                      style: TextStyle(
                        color: Colors.blue[700],
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ),
                Expanded(
                  flex: 3, // 合并成绩、学分、GPA
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      border: Border(
                        left: BorderSide(color: Colors.blue[200]!),
                      ),
                    ),
                    child: Text(
                      '成绩 / 学分 / GPA',
                      style: TextStyle(
                        color: Colors.blue[700],
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // 表格内容
          Expanded(
            child: ListView.builder(
              itemCount: _filteredGrades.length,
              itemBuilder: (context, index) {
                final grade = _filteredGrades[index];
                final scoreColor = _getScoreColor(grade.score);
                return Container(
                  decoration: BoxDecoration(
                    color: index.isEven ? Colors.grey[50] : Colors.white,
                    border: Border(
                      bottom: BorderSide(color: Colors.grey[200]!),
                    ),
                  ),
                  child: InkWell(
                    onTap: () => _showGradeDetail(grade),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(
                          flex: 1,
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            child: Text(
                              '${index + 1}',
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 13,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                        Expanded(
                          flex: 2,
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              border: Border(
                                left: BorderSide(color: Colors.blue[200]!),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  grade.courseName,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.orange[100],
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    grade.courseAttr,
                                    style: TextStyle(
                                      color: Colors.orange[800],
                                      fontSize: 10,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        Expanded(
                          flex: 3,
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              border: Border(
                                left: BorderSide(color: Colors.blue[200]!),
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: [
                                Text(
                                  grade.score,
                                  style: TextStyle(
                                    color: scoreColor.withOpacity(0.8),
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                  ),
                                ),
                                Container(
                                  margin: const EdgeInsets.symmetric(horizontal: 4),
                                  width: 1,
                                  height: 18,
                                  color: Colors.grey[300],
                                ),
                                Text(
                                  grade.credit,
                                  style: TextStyle(
                                    color: Colors.grey[700],
                                    fontSize: 13,
                                  ),
                                ),
                                Container(
                                  margin: const EdgeInsets.symmetric(horizontal: 4),
                                  width: 1,
                                  height: 18,
                                  color: Colors.grey[300],
                                ),
                                Text(
                                  grade.gpa,
                                  style: TextStyle(
                                    color: Colors.purple[700],
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  /// 弹出单条成绩详情对话框
  void _showGradeDetail(GradeEntry grade) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.grade, color: Colors.blue[600], size: 24),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                grade.courseName,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _DetailRow('课程代码', grade.courseCode, Icons.code),
            _DetailRow('成绩', grade.score, Icons.score),
            _DetailRow('学分', grade.credit, Icons.star),
            _DetailRow('GPA', grade.gpa, Icons.trending_up),
            _DetailRow('学时', grade.totalHours, Icons.access_time),
            _DetailRow('课程属性', grade.courseAttr, Icons.category),
            _DetailRow('课程性质', grade.courseNature, Icons.school),
            _DetailRow('考试类型', grade.examType, Icons.quiz),
            if (grade.generalType.isNotEmpty)
              _DetailRow('通选课类别', grade.generalType, Icons.label),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('关闭'),
          ),
        ],
      ),
    );
  }

  /// 详情项行：左侧为标签与图标，右侧为值
  Widget _DetailRow(String label, String value, IconData icon) {
    if (value.isEmpty) return const SizedBox.shrink();
    
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(icon, color: Colors.grey[600], size: 18),
          const SizedBox(width: 12),
          SizedBox(
            width: 80,
            child: Text(
              '$label：',
              style: TextStyle(
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  /// 将分数区间映射为不同颜色，便于快速识别成绩水平
  Color _getScoreColor(String score) {
    final scoreValue = double.tryParse(score) ?? 0;
    if (scoreValue >= 90) return Colors.green;
    if (scoreValue >= 80) return Colors.blue;
    if (scoreValue >= 70) return Colors.orange;
    if (scoreValue >= 60) return Colors.yellow.shade700;
    return Colors.red;
  }

  /// 计算当前过滤结果的平均分（保留 1 位小数）
  String _calculateAverageScore() {
    if (_filteredGrades.isEmpty) return '0.0';
    
    double total = 0;
    int count = 0;
    
    for (final grade in _filteredGrades) {
      final score = double.tryParse(grade.score);
      if (score != null) {
        total += score;
        count++;
      }
    }
    
    if (count == 0) return '0.0';
    return (total / count).toStringAsFixed(1);
  }
}


