import 'announcement.dart';
import 'complaint.dart';
import 'lost_found.dart';

enum FeedItemType { complaint, lostFound, announcement }

sealed class FeedItem {
  const FeedItem();

  DateTime? get createdAt;
  FeedItemType get type;
  String get id;
}

class ComplaintFeedItem extends FeedItem {
  const ComplaintFeedItem(this.complaint);

  final Complaint complaint;

  @override
  DateTime? get createdAt => complaint.createdAt;

  @override
  FeedItemType get type => FeedItemType.complaint;

  @override
  String get id => 'complaint_${complaint.complaintId}';
}

class LostFoundFeedItem extends FeedItem {
  const LostFoundFeedItem(this.item);

  final LostFound item;

  @override
  DateTime? get createdAt => item.createdAt;

  @override
  FeedItemType get type => FeedItemType.lostFound;

  @override
  String get id => 'lost_found_${item.itemId}';
}

class AnnouncementFeedItem extends FeedItem {
  const AnnouncementFeedItem(this.announcement);

  final Announcement announcement;

  @override
  DateTime? get createdAt => announcement.createdAt;

  @override
  FeedItemType get type => FeedItemType.announcement;

  @override
  String get id => 'announcement_${announcement.announcementId}';
}
