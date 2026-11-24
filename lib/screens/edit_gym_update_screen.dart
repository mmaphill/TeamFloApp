import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../config/colors.dart';
import '../models/gym_update_model.dart';
import '../services/attendance_stats_service.dart';
import '../services/gym_update_service.dart';

/// GYM UPDATES: the form for a new update, or for editing one
/// ([existing] set). Heading, description, one optional picture or video,
/// an optional event date, and (new updates only) "Notify members".
class EditGymUpdateScreen extends StatefulWidget {
  final GymUpdate? existing;

  const EditGymUpdateScreen({super.key, this.existing});

  @override
  State<EditGymUpdateScreen> createState() => _EditGymUpdateScreenState();
}

class _EditGymUpdateScreenState extends State<EditGymUpdateScreen> {
  static const int _maxTitle = 100;
  static const int _maxDescription = 5000;

  final GymUpdateService _service = GymUpdateService();
  final ImagePicker _picker = ImagePicker();
  late final TextEditingController _titleController;
  late final TextEditingController _descriptionController;

  DateTime? _eventDate;
  bool _notify = false;
  bool _saving = false;

  // Media: a newly picked file, or the existing one, or neither
  File? _newMediaFile;
  String? _newMediaType;
  bool _removeExistingMedia = false;

  bool get _isEditing => widget.existing != null;

  bool get _hasExistingMedia =>
      (widget.existing?.hasMedia ?? false) && !_removeExistingMedia && _newMediaFile == null;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _titleController = TextEditingController(text: e?.title ?? '');
    _descriptionController = TextEditingController(text: e?.description ?? '');
    _eventDate = e?.eventDate;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  // ---------- Actions ----------

  Future<void> _pickImage() async {
    final picked = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1920,
      imageQuality: 85, // keeps uploads small without visible loss
    );
    if (picked == null) return;
    setState(() {
      _newMediaFile = File(picked.path);
      _newMediaType = GymUpdate.typeImage;
    });
  }

  Future<void> _pickVideo() async {
    final picked = await _picker.pickVideo(
      source: ImageSource.gallery,
      maxDuration: const Duration(minutes: 3),
    );
    if (picked == null) return;

    // Storage rules allow up to 200 MB; check here for a friendlier message
    final file = File(picked.path);
    final int bytes = await file.length();
    if (bytes > 200 * 1024 * 1024) {
      _showMessage('That video is too large (max 200 MB). Try a shorter clip.');
      return;
    }
    setState(() {
      _newMediaFile = file;
      _newMediaType = GymUpdate.typeVideo;
    });
  }

  void _removeMedia() {
    setState(() {
      _newMediaFile = null;
      _newMediaType = null;
      if (widget.existing?.hasMedia ?? false) _removeExistingMedia = true;
    });
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final picked = await showDatePicker(
      context: context,
      initialDate: (_eventDate != null && !_eventDate!.isBefore(today)) ? _eventDate! : today,
      firstDate: today,
      lastDate: DateTime(now.year + 2, now.month, now.day),
    );
    if (picked != null) setState(() => _eventDate = picked);
  }

  Future<void> _save() async {
    final title = _titleController.text.trim();
    final description = _descriptionController.text.trim();
    if (title.isEmpty) {
      _showMessage('Add a heading first');
      return;
    }

    setState(() => _saving = true);
    try {
      if (_isEditing) {
        await _service.edit(
          widget.existing!,
          title: title,
          description: description,
          eventDate: _eventDate,
          newMediaFile: _newMediaFile,
          newMediaType: _newMediaType,
          removeMedia: _removeExistingMedia,
        );
      } else {
        await _service.create(
          title: title,
          description: description,
          eventDate: _eventDate,
          notify: _notify,
          mediaFile: _newMediaFile,
          mediaType: _newMediaType,
        );
      }
      if (!mounted) return;
      Navigator.pop(context);
      _showMessage(_isEditing ? 'Update saved' : 'Update posted');
    } catch (e) {
      _showMessage('Could not save: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _showMessage(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  // ---------- UI ----------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: _saving ? null : () => Navigator.pop(context),
        ),
        title: Text(_isEditing ? 'Edit Update' : 'New Update'),
        backgroundColor: context.colors.appBar,
      ),
      body: AbsorbPointer(
        absorbing: _saving, // no changes while it uploads
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextField(
              controller: _titleController,
              maxLength: _maxTitle,
              textCapitalization: TextCapitalization.sentences,
              decoration: _inputDecoration('Heading'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _descriptionController,
              maxLength: _maxDescription,
              minLines: 4,
              maxLines: 10,
              textCapitalization: TextCapitalization.sentences,
              decoration: _inputDecoration('Description (optional)'),
            ),
            const SizedBox(height: 16),

            _sectionLabel('Picture or video (optional)'),
            _mediaPreview(),
            const SizedBox(height: 8),
            Row(
              children: [
                OutlinedButton.icon(
                  onPressed: _pickImage,
                  icon: const Icon(Icons.image),
                  label: const Text('Photo'),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: _pickVideo,
                  icon: const Icon(Icons.videocam),
                  label: const Text('Video'),
                ),
                const Spacer(),
                if (_newMediaFile != null || _hasExistingMedia)
                  TextButton(
                    onPressed: _removeMedia,
                    child: const Text('Remove', style: TextStyle(color: AppColors.error)),
                  ),
              ],
            ),
            const SizedBox(height: 16),

            _sectionLabel('Event date (optional)'),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.event),
              title: Text(_eventDate == null ? 'No date' : AttendanceStats.shortDate(_eventDate!)),
              subtitle: const Text('Dated updates hide after the event day'),
              trailing: _eventDate == null
                  ? null
                  : IconButton(
                icon: const Icon(Icons.clear),
                tooltip: 'Remove date',
                onPressed: () => setState(() => _eventDate = null),
              ),
              onTap: _pickDate,
            ),

            // Notifications only go out for new updates, not edits
            if (!_isEditing)
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Notify members'),
                subtitle: const Text('Sends a push notification to everyone in the gym'),
                value: _notify,
                onChanged: (v) => setState(() => _notify = v),
              ),
            const SizedBox(height: 24),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: context.colors.primary,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                onPressed: _saving ? null : _save,
                child: _saving
                    ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(AppColors.onPrimary),
                  ),
                )
                    : Text(
                  _isEditing ? 'Save' : 'Post',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.onPrimary,
                  ),
                ),
              ),
            ),
            if (_saving && _newMediaType == GymUpdate.typeVideo)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text(
                  'Uploading video. This can take a minute.',
                  textAlign: TextAlign.center,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _mediaPreview() {
    const double height = 180;

    // A newly picked picture
    if (_newMediaFile != null && _newMediaType == GymUpdate.typeImage) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image.file(_newMediaFile!, height: height, width: double.infinity, fit: BoxFit.cover),
      );
    }
    // A newly picked video (not played here, just confirmed)
    if (_newMediaFile != null) {
      return _placeholder(Icons.videocam, 'Video selected', height);
    }
    // The update's current media
    if (_hasExistingMedia) {
      final e = widget.existing!;
      if (e.isVideo) return _placeholder(Icons.videocam, 'Current video', height);
      return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image.network(e.mediaUrl!, height: height, width: double.infinity, fit: BoxFit.cover),
      );
    }
    return const SizedBox.shrink();
  }

  Widget _placeholder(IconData icon, String text, double height) {
    return Container(
      height: height,
      width: double.infinity,
      decoration: BoxDecoration(
        color: context.colors.surfaceHigh,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 40),
          const SizedBox(height: 8),
          Text(text),
        ],
      ),
    );
  }

  Widget _sectionLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w600),
      ),
    );
  }

  InputDecoration _inputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      alignLabelWithHint: true,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: context.colors.primary, width: 2),
      ),
    );
  }
}
