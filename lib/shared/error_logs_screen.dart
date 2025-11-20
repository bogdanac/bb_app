import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_colors.dart';
import 'error_logger.dart';
import 'snackbar_utils.dart';

class ErrorLogsScreen extends StatefulWidget {
  const ErrorLogsScreen({super.key});

  @override
  State<ErrorLogsScreen> createState() => _ErrorLogsScreenState();
}

class _ErrorLogsScreenState extends State<ErrorLogsScreen> {
  List<Map<String, dynamic>> _logs = [];
  List<Map<String, dynamic>> _filteredLogs = [];
  bool _isLoading = true;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadLogs();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadLogs() async {
    setState(() => _isLoading = true);
    final logs = await ErrorLogger.getLocalLogs();
    setState(() {
      _logs = logs;
      _filterLogs();
      _isLoading = false;
    });
  }

  void _filterLogs() {
    if (_searchQuery.isEmpty) {
      _filteredLogs = _logs;
    } else {
      final query = _searchQuery.toLowerCase();
      _filteredLogs = _logs.where((log) {
        final source = (log['source'] ?? '').toString().toLowerCase();
        final error = (log['error'] ?? '').toString().toLowerCase();
        final stackTrace = (log['stackTrace'] ?? '').toString().toLowerCase();
        final context = (log['context'] ?? '').toString().toLowerCase();

        return source.contains(query) ||
               error.contains(query) ||
               stackTrace.contains(query) ||
               context.contains(query);
      }).toList();
    }
  }

  void _onSearchChanged(String query) {
    setState(() {
      _searchQuery = query;
      _filterLogs();
    });
  }

  Future<void> _clearLogs() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear Error Logs'),
        content: const Text('Are you sure you want to clear all local error logs?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Clear'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await ErrorLogger.clearLocalLogs();
      await _loadLogs();
      if (mounted) {
        SnackBarUtils.showSuccess(context, 'Error logs cleared');
      }
    }
  }

  Future<void> _copyLogToClipboard(Map<String, dynamic> log) async {
    final logText = '''
Source: ${log['source']}
Error: ${log['error']}
Timestamp: ${log['timestamp']}
Platform: ${log['platform']}
${log['stackTrace'] != null ? 'Stack Trace:\n${log['stackTrace']}\n' : ''}${log['context'] != null ? 'Context:\n${log['context']}\n' : ''}
''';
    await Clipboard.setData(ClipboardData(text: logText));
    if (mounted) {
      SnackBarUtils.showSuccess(context, 'Log copied to clipboard');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Error Logs'),
        backgroundColor: AppColors.transparent,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadLogs,
            tooltip: 'Refresh',
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: _logs.isEmpty ? null : _clearLogs,
            tooltip: 'Clear all logs',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: TextField(
                    controller: _searchController,
                    onChanged: _onSearchChanged,
                    decoration: InputDecoration(
                      hintText: 'Search logs...',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () {
                                _searchController.clear();
                                _onSearchChanged('');
                              },
                            )
                          : null,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
                if (_logs.isEmpty)
                  const Expanded(
                    child: Center(
                      child: Text(
                        'No error logs found',
                        style: TextStyle(color: AppColors.white70),
                      ),
                    ),
                  )
                else if (_filteredLogs.isEmpty)
                  const Expanded(
                    child: Center(
                      child: Text(
                        'No logs match your search',
                        style: TextStyle(color: AppColors.white70),
                      ),
                    ),
                  )
                else
                  Expanded(
                    child: ListView.builder(
                      padding: const EdgeInsets.all(8),
                      itemCount: _filteredLogs.length,
                      itemBuilder: (context, index) {
                        final log = _filteredLogs[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ExpansionTile(
                        title: Text(
                          log['source'] ?? 'Unknown source',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(
                          log['error'] ?? 'No error message',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.copy, size: 20),
                          onPressed: () => _copyLogToClipboard(log),
                          tooltip: 'Copy log',
                        ),
                        children: [
                          Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildLogRow('Timestamp', log['timestamp']),
                                _buildLogRow('Platform', log['platform']),
                                if (log['context'] != null) ...[
                                  const SizedBox(height: 8),
                                  const Text(
                                    'Context:',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.white,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    log['context'].toString(),
                                    style: const TextStyle(
                                      fontFamily: 'monospace',
                                      fontSize: 12,
                                      color: AppColors.white70,
                                    ),
                                  ),
                                ],
                                if (log['stackTrace'] != null) ...[
                                  const SizedBox(height: 8),
                                  const Text(
                                    'Stack Trace:',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.white,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    log['stackTrace'].toString(),
                                    style: const TextStyle(
                                      fontFamily: 'monospace',
                                      fontSize: 10,
                                      color: AppColors.white60,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                        );
                      },
                    ),
                  ),
              ],
            ),
    );
  }

  Widget _buildLogRow(String label, dynamic value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: AppColors.white,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value?.toString() ?? 'N/A',
              style: const TextStyle(color: AppColors.white70),
            ),
          ),
        ],
      ),
    );
  }
}
