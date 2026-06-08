import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:snagsnapper/Constants/constants.dart';
import 'package:snagsnapper/Data/contentProvider.dart';
import 'package:snagsnapper/Data/models/snag.dart';
import 'package:snagsnapper/Data/models/priority_level.dart';

class SnagCardView extends StatelessWidget {
  final Snag snag;
  final VoidCallback callBack;

  const SnagCardView({required this.snag, required this.callBack, super.key});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: callBack,
      child: Card(
        color: Colors.white,
        margin: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
        child: SizedBox(
          height: 100.0,
          child: Row(
            children: <Widget>[
              // Image container
              Container(
                width: 100.0,
                decoration: BoxDecoration(
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(5.0),
                    bottomLeft: Radius.circular(5.0),
                  ),
                  color: Colors.grey[200],
                ),
                child: ClipRRect(
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(5.0),
                    bottomLeft: Radius.circular(5.0),
                  ),
                  child: _buildSnagImage(),
                ),
              ),
              Expanded(
                child: Container(
                  margin: const EdgeInsets.only(left: 8.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: <Widget>[
                      Row(
                        children: <Widget>[
                          Icon(
                            Icons.location_on,
                            size: 20.0,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                          Expanded(
                            child: Text(
                              ' ${snag.location ?? "No location"}',
                              style: const TextStyle(
                                fontSize: 13.0,
                                fontWeight: FontWeight.w500,
                                fontStyle: FontStyle.normal,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      Row(
                        children: <Widget>[
                          Icon(
                            Icons.calendar_today,
                            size: 20.0,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                          Text(
                            snag.dueDate == null
                                ? ' No due-date assigned'
                                // TIMEZONE: Display UTC midnight as local date
                                : ' ${DateFormat(Provider.of<CP>(context).getDateFormat()).format(snag.dueDate!.toLocal())}',
                            style: const TextStyle(
                              fontSize: 13.0,
                              fontWeight: FontWeight.w500,
                              fontStyle: FontStyle.normal,
                            ),
                          ),
                        ],
                      ),
                      Row(
                        children: <Widget>[
                          Icon(
                            Icons.person,
                            size: 20.0,
                            color: snag.assignedEmail?.toLowerCase() ==
                                    Provider.of<CP>(context).getAppUser()?.email.toLowerCase()
                                ? Colors.green[600]
                                : Theme.of(context).colorScheme.primary,
                          ),
                          Text(
                            snag.assignedName == null || snag.assignedName!.isEmpty
                                ? ' Not assigned  '
                                : ' ${snag.assignedName!}  ',
                            style: const TextStyle(
                              fontSize: 13.0,
                              fontWeight: FontWeight.w500,
                              fontStyle: FontStyle.normal,
                            ),
                          ),
                          Icon(
                            Icons.add_alert,
                            size: 20.0,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                          Text(
                            _getPriorityLabel(snag.priority),
                            style: const TextStyle(
                              fontSize: 13.0,
                              fontWeight: FontWeight.w500,
                              fontStyle: FontStyle.normal,
                            ),
                          ),
                          Text(
                            !snag.snagStatus && !snag.snagConfirmedStatus ? ' (closed)' : '',
                            style: TextStyle(
                              fontSize: 12.0,
                              fontWeight: FontWeight.w900,
                              fontStyle: _isHighSeverity(snag.priority) ? FontStyle.italic : FontStyle.normal,
                            ),
                          ),
                        ],
                      )
                    ],
                  ),
                ),
              ),
              Container(
                width: 10.0,
                decoration: BoxDecoration(
                  color: _getStatusColor(context),
                  borderRadius: const BorderRadius.only(
                    topRight: Radius.circular(5.0),
                    bottomRight: Radius.circular(5.0),
                  ),
                ),
              )
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSnagImage() {
    // Check if first image slot has an image
    final firstSlot = snag.images.isNotEmpty ? snag.images[0] : null;
    if (firstSlot == null || !firstSlot.hasImage) {
      return Image.asset(
        'images/1024LowPoly.png',
        fit: BoxFit.cover,
        width: 100,
        height: 100,
      );
    }

    // Load image from local file path
    return FutureBuilder<String>(
      future: _getAbsolutePath(firstSlot.localPath!),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator(strokeWidth: 2));
        }
        final file = File(snapshot.data!);
        if (!file.existsSync()) {
          return Image.asset('images/1024LowPoly.png', fit: BoxFit.cover);
        }
        return Image.file(file, fit: BoxFit.cover, width: 100, height: 100);
      },
    );
  }

  Future<String> _getAbsolutePath(String relativePath) async {
    final appDir = await getApplicationDocumentsDirectory();
    return '${appDir.path}/$relativePath';
  }

  /// Get label for priority code
  /// Returns the code itself with leading space for display
  String _getPriorityLabel(String? priority) {
    if (priority == null || priority.isEmpty) return ' None';
    return ' $priority';
  }

  /// Check if priority is high severity (CAT1 or CAT2)
  bool _isHighSeverity(String? priority) {
    if (priority == null || priority.isEmpty) return false;
    return priority == 'CAT1' || priority == 'CAT2';
  }

  // TIMEZONE: Convert UTC midnight to local for comparison
  Color _getStatusColor(BuildContext context) {
    // snagConfirmedStatus will be false once it is closed confirmed
    if (!snag.snagConfirmedStatus) return Colors.white;
    if (snag.dueDate == null) return Colors.white;

    final daysLeft = snag.dueDate!.toLocal().difference(DateTime.now()).inDays;
    final cp = Provider.of<CP>(context);

    if (daysLeft >= cp.greenCondition) {
      return greenCardView;
    } else if (daysLeft >= cp.orangeCondition) {
      return orangeCardView;
    } else {
      return redCardView;
    }
  }
}
