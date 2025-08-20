// 通用现代表格组件：支持搜索、筛选、分页、选择与行操作
// 适用于通用数据列表的展示，调用方通过 [columns] 与 [rowBuilder] 自由渲染单元格
import 'package:flutter/material.dart';

/// 通用表格组件
///
/// - columns: 表头列定义（名称、布局）
/// - data: 数据源列表
/// - rowBuilder: 用于渲染每一行的构建函数
/// - searchable/filterable: 是否启用搜索/筛选区域
/// - paginated/itemsPerPage: 是否分页与每页条数
/// - selectable: 是否多选，并通过 [onSelectionChanged] 通知外部
class ModernTable<T> extends StatefulWidget {
  const ModernTable({
    super.key,
    required this.columns,
    required this.data,
    required this.rowBuilder,
    this.searchable = true,
    this.filterable = false,
    this.paginated = false,
    this.itemsPerPage = 10,
    this.searchHint = '搜索...',
    this.emptyMessage = '暂无数据',
    this.loading = false,
    this.onRefresh,
    this.searchFields,
    this.filterOptions,
    this.onFilterChanged,
    this.headerActions,
    this.rowActions,
    this.onRowTap,
    this.selectable = false,
    this.onSelectionChanged,
  });

  final List<TableColumn> columns;
  final List<T> data;
  final Widget Function(T item, int index) rowBuilder;
  final bool searchable;
  final bool filterable;
  final bool paginated;
  final int itemsPerPage;
  final String searchHint;
  final String emptyMessage;
  final bool loading;
  final VoidCallback? onRefresh;
  final List<String>? searchFields;
  final List<String>? filterOptions;
  final Function(String?)? onFilterChanged;
  final List<Widget>? headerActions;
  final List<Widget>? rowActions;
  final Function(T item)? onRowTap;
  final bool selectable;
  final Function(List<T> selected)? onSelectionChanged;

  @override
  State<ModernTable<T>> createState() => _ModernTableState<T>();
}

/// 表格内部状态：维护搜索、筛选、分页与选中项
class _ModernTableState<T> extends State<ModernTable<T>> {
  final TextEditingController _searchController = TextEditingController();
  String? _selectedFilter;
  List<T> _filteredData = [];
  List<T> _selectedItems = [];
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_filterData);
    _filteredData = widget.data;
  }

  @override
  void didUpdateWidget(ModernTable<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.data != widget.data) {
      _filteredData = widget.data;
      _currentPage = 0;
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  /// 根据关键词与筛选条件过滤数据
  ///
  /// 默认行为：
  /// - 若未指定 [searchFields]，则调用 `toString()` 做简单包含匹配
  /// - 若指定 [searchFields]，需由业务层实现具体匹配逻辑（此处保持不过滤）
  void _filterData() {
    final query = _searchController.text.toLowerCase();
    final filter = _selectedFilter; // 保留占位，避免破坏现有布局逻辑
    
    setState(() {
      _filteredData = widget.data.where((item) {
        // 搜索过滤
        if (query.isNotEmpty) {
          bool matchesSearch = false;
          if (widget.searchFields != null) {
            // 这里保留给业务层定制：若需要针对字段匹配，请在上层传入已过滤的数据
            matchesSearch = true;
          } else {
            // 默认搜索所有字符串字段
            matchesSearch = item.toString().toLowerCase().contains(query);
          }
          if (!matchesSearch) return false;
        }
        
        // 类型过滤
        if (filter != null && widget.onFilterChanged != null) {
          // 交由业务侧的 onFilterChanged 响应实际逻辑，此处不过滤
          return true;
        }
        
        return true;
      }).toList();
      
      _currentPage = 0;
    });
  }

  /// 本地更新筛选值，并回调外部处理额外逻辑
  void _onFilterChanged(String? value) {
    setState(() {
      _selectedFilter = value; // 兼容旧用法
    });
    _filterData();
    widget.onFilterChanged?.call(value);
  }

  /// 行点击：若可选中则切换选择状态，同时触发外部行点击回调
  void _onRowTap(T item) {
    if (widget.selectable) {
      setState(() {
        if (_selectedItems.contains(item)) {
          _selectedItems.remove(item);
        } else {
          _selectedItems.add(item);
        }
      });
      widget.onSelectionChanged?.call(_selectedItems);
    }
    widget.onRowTap?.call(item);
  }

  /// 当前页数据切片
  List<T> get _paginatedData {
    if (!widget.paginated) return _filteredData;
    final start = _currentPage * widget.itemsPerPage;
    final end = (start + widget.itemsPerPage).clamp(0, _filteredData.length);
    return _filteredData.sublist(start, end);
  }

  /// 总页数
  int get _totalPages => (_filteredData.length / widget.itemsPerPage).ceil();

  @override
  /// 表格整体布局：顶部搜索/筛选区，中间表头+行列表，底部分页
  Widget build(BuildContext context) {
    return Column(
      children: [
        // 搜索和筛选区域
        if (widget.searchable || widget.filterable)
          Container(
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                if (widget.searchable) ...[
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.grey[50],
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey[200]!),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.search, color: Colors.grey[600], size: 20),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextField(
                              controller: _searchController,
                              decoration: InputDecoration(
                                hintText: widget.searchHint,
                                border: InputBorder.none,
                                hintStyle: TextStyle(color: Colors.grey[500]),
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
                  const SizedBox(width: 16),
                ],
                if (widget.filterable && widget.filterOptions != null) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: Colors.grey[50],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey[200]!),
                    ),
                    child: DropdownButton<String?>(
                      value: _selectedFilter, // 兼容旧用法
                      underline: const SizedBox.shrink(),
                      hint: const Text('筛选'),
                      items: [
                        const DropdownMenuItem<String?>(value: null, child: Text('全部')),
                        ...widget.filterOptions!.map((option) => DropdownMenuItem<String?>(
                              value: option,
                              child: Text(option),
                            )),
                      ],
                      onChanged: _onFilterChanged,
                    ),
                  ),
                  const SizedBox(width: 16),
                ],
                if (widget.headerActions != null) ...widget.headerActions!,
              ],
            ),
          ),

        // 表格内容
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              children: [
                // 表头
                Container(
                  decoration: BoxDecoration(
                    color: Colors.grey[50],
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(12),
                      topRight: Radius.circular(12),
                    ),
                  ),
                  child: Row(
                    children: [
                      if (widget.selectable) ...[
                        SizedBox(
                          width: 60,
                          child: Checkbox(
                            value: _selectedItems.length == _filteredData.length && _filteredData.isNotEmpty,
                            onChanged: (value) {
                              setState(() {
                                if (value == true) {
                                  _selectedItems = List.from(_filteredData);
                                } else {
                                  _selectedItems.clear();
                                }
                              });
                              widget.onSelectionChanged?.call(_selectedItems);
                            },
                          ),
                        ),
                      ],
                      ...widget.columns.map((column) => Expanded(
                        flex: column.flex ?? 1,
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          child: Text(
                            column.label,
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: Colors.grey[700],
                            ),
                            textAlign: column.textAlign ?? TextAlign.start,
                          ),
                        ),
                      )),
                      if (widget.rowActions != null)
                        SizedBox(
                          width: 100,
                          child: Text(
                            '操作',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: Colors.grey[700],
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                    ],
                  ),
                ),

                // 表格行
                Expanded(
                  child: widget.loading
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
                      : _filteredData.isEmpty
                          ? _buildEmptyState()
                          : ListView.builder(
                              itemCount: _paginatedData.length,
                              itemBuilder: (context, index) {
                                final item = _paginatedData[index];
                                final globalIndex = _currentPage * widget.itemsPerPage + index;
                                final isSelected = _selectedItems.contains(item);
                                
                                return Container(
                                  decoration: BoxDecoration(
                                    color: isSelected ? Colors.blue[50] : null,
                                    border: Border(
                                      bottom: BorderSide(color: Colors.grey[200]!),
                                    ),
                                  ),
                                  child: InkWell(
                                    onTap: () => _onRowTap(item),
                                    child: Row(
                                      children: [
                                        if (widget.selectable) ...[
                                          SizedBox(
                                            width: 60,
                                            child: Checkbox(
                                              value: isSelected,
                                              onChanged: (value) {
                                                setState(() {
                                                  if (value == true) {
                                                    _selectedItems.add(item);
                                                  } else {
                                                    _selectedItems.remove(item);
                                                  }
                                                });
                                                widget.onSelectionChanged?.call(_selectedItems);
                                              },
                                            ),
                                          ),
                                        ],
                                        Expanded(
                                          child: widget.rowBuilder(item, globalIndex),
                                        ),
                                        if (widget.rowActions != null)
                                          SizedBox(
                                            width: 100,
                                            child: Row(
                                              mainAxisAlignment: MainAxisAlignment.center,
                                              children: widget.rowActions!
                                                  .map((action) => action)
                                                  .toList(),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                ),

                // 分页
                if (widget.paginated && _totalPages > 1)
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.grey[50],
                      borderRadius: const BorderRadius.only(
                        bottomLeft: Radius.circular(12),
                        bottomRight: Radius.circular(12),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '共 ${_filteredData.length} 条记录',
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                        Row(
                          children: [
                            IconButton(
                              onPressed: _currentPage > 0
                                  ? () => setState(() => _currentPage--)
                                  : null,
                              icon: const Icon(Icons.chevron_left),
                            ),
                            Text(
                              '${_currentPage + 1} / $_totalPages',
                              style: TextStyle(color: Colors.grey[700]),
                            ),
                            IconButton(
                              onPressed: _currentPage < _totalPages - 1
                                  ? () => setState(() => _currentPage++)
                                  : null,
                              icon: const Icon(Icons.chevron_right),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

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
            _searchController.text.isNotEmpty ? '未找到相关数据' : widget.emptyMessage,
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
}

class TableColumn {
  const TableColumn({
    required this.label,
    this.flex,
    this.textAlign,
  });

  final String label;
  final int? flex;
  final TextAlign? textAlign;
}
