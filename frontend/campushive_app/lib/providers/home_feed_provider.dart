import 'package:flutter/foundation.dart';

import '../models/announcement.dart';
import '../models/complaint.dart';
import '../models/feed_item.dart';
import '../models/lost_found.dart';
import '../services/announcement_service.dart';
import '../services/complaint_service.dart';
import '../services/lost_found_service.dart';

class HomeFeedProvider extends ChangeNotifier {
  HomeFeedProvider({
    ComplaintService? complaintService,
    LostFoundService? lostFoundService,
    AnnouncementService? announcementService,
  }) : _complaintService = complaintService ?? ComplaintService(),
       _lostFoundService = lostFoundService ?? LostFoundService(),
       _announcementService = announcementService ?? AnnouncementService();

  final ComplaintService _complaintService;
  final LostFoundService _lostFoundService;
  final AnnouncementService _announcementService;

  List<FeedItem> _items = const [];
  bool _isLoading = false;
  String? _errorMessage;

  final Set<int> _supportingComplaintIds = <int>{};
  final Set<int> _supportedComplaintIds = <int>{};
  final Map<int, int> _supportCountOverrides = <int, int>{};

  final Set<int> _likingAnnouncementIds = <int>{};
  final Map<int, bool> _likedAnnouncementOverrides = <int, bool>{};
  final Map<int, int> _likeCountOverrides = <int, int>{};

  List<FeedItem> get items => _items;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get isEmpty => _items.isEmpty;

  bool isSupportingComplaint(int complaintId) =>
      _supportingComplaintIds.contains(complaintId);

  bool isComplaintSupported(Complaint complaint) =>
      _supportedComplaintIds.contains(complaint.complaintId) ||
      complaint.isSupported;

  int getSupportCount(Complaint complaint) =>
      _supportCountOverrides[complaint.complaintId] ?? complaint.supportCount;

  bool isLikingAnnouncement(int announcementId) =>
      _likingAnnouncementIds.contains(announcementId);

  bool isAnnouncementLiked(Announcement announcement) =>
      _likedAnnouncementOverrides[announcement.announcementId] ??
      announcement.isLiked;

  int getAnnouncementLikeCount(Announcement announcement) =>
      _likeCountOverrides[announcement.announcementId] ??
      announcement.likeCount;

  Future<void> loadFeed({bool refresh = false}) async {
    if (_isLoading) return;
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final results = await Future.wait([
        _fetchRecentComplaints(),
        _fetchRecentLostFound(),
        _fetchRecentAnnouncements(),
      ]);

      final complaints = results[0] as List<Complaint>;
      final lostFounds = results[1] as List<LostFound>;
      final announcements = results[2] as List<Announcement>;

      final cutoff = DateTime.now().subtract(const Duration(days: 7));

      final List<FeedItem> combined = [
        ...complaints
            .where((c) => c.createdAt != null && c.createdAt!.isAfter(cutoff))
            .map((c) => ComplaintFeedItem(c)),
        ...lostFounds
            .where(
              (lf) => lf.createdAt != null && lf.createdAt!.isAfter(cutoff),
            )
            .map((lf) => LostFoundFeedItem(lf)),
        ...announcements
            .where((a) => a.createdAt != null && a.createdAt!.isAfter(cutoff))
            .map((a) => AnnouncementFeedItem(a)),
      ];

      combined.sort((a, b) {
        final dateA = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        final dateB = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        return dateB.compareTo(dateA);
      });

      _items = combined;
      _errorMessage = null;
    } catch (e) {
      if (_items.isEmpty) {
        _errorMessage = e is ComplaintException
            ? e.message
            : e is LostFoundException
            ? e.message
            : e is AnnouncementException
            ? e.message
            : 'Unable to load home feed.';
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<List<Complaint>> _fetchRecentComplaints() async {
    try {
      final page = await _complaintService.fetchComplaints(
        page: 1,
        perPage: 50,
      );
      return page.complaints;
    } catch (_) {
      return const [];
    }
  }

  Future<List<LostFound>> _fetchRecentLostFound() async {
    try {
      final page = await _lostFoundService.fetchItems(page: 1, perPage: 50);
      return page.items;
    } catch (_) {
      return const [];
    }
  }

  Future<List<Announcement>> _fetchRecentAnnouncements() async {
    try {
      final page = await _announcementService.fetchAnnouncements(
        page: 1,
        perPage: 50,
      );
      return page.announcements;
    } catch (_) {
      return const [];
    }
  }

  Future<String?> supportComplaint(int complaintId) async {
    if (_supportingComplaintIds.contains(complaintId)) return null;
    _supportingComplaintIds.add(complaintId);
    notifyListeners();

    try {
      final newCount = await _complaintService.supportComplaint(complaintId);
      _supportCountOverrides[complaintId] = newCount;
      _supportedComplaintIds.add(complaintId);
      return null;
    } on ComplaintException catch (e) {
      if (e.message.toLowerCase().contains('already supported')) {
        _supportedComplaintIds.add(complaintId);
      }
      return e.message;
    } catch (_) {
      return 'Failed to support complaint.';
    } finally {
      _supportingComplaintIds.remove(complaintId);
      notifyListeners();
    }
  }

  Future<void> toggleAnnouncementLike(int announcementId) async {
    if (_likingAnnouncementIds.contains(announcementId)) return;
    _likingAnnouncementIds.add(announcementId);
    notifyListeners();

    try {
      final result = await _announcementService.toggleLike(announcementId);
      _likedAnnouncementOverrides[announcementId] = result.isLiked;
      _likeCountOverrides[announcementId] = result.likeCount;
    } catch (_) {
    } finally {
      _likingAnnouncementIds.remove(announcementId);
      notifyListeners();
    }
  }
}
