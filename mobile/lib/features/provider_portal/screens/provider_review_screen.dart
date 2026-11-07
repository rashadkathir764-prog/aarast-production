import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../../../core/experience_v3/aarast_v3.dart';
import '../../../core/widgets/aarast_toast.dart';
import '../../../core/widgets/aarast_ui.dart';
import '../../marketplace/marketplace_api.dart'
    show ProviderReview, reportProviderReview;
import '../providers/provider_dashboard_provider.dart';
import '../widgets/provider_profile_parts.dart'
    show ProviderReviewCard, ProviderReviewReplyBox;

/// p27 «تقييم جديد»: one review of his and his one reply (B-09). The notice
/// «تقييم جديد» (p42) and the reviews of «ملفي» open it. Before he replies:
/// the box «ردك (مرة وحدة، يشوفه الكل)» and «انشر الرد». After: his reply as
/// customers read it under the review, or that the team hid it. p27's
/// «فيه كلام مسيء أو كذب؟ بلّغ عنه» reports a published review to the team
/// (RA-ST-05, D94). The design's occasion line and tags have no field (F15).
class ProviderReviewScreen extends StatefulWidget {
  const ProviderReviewScreen({required this.reviewId, super.key});

  final String reviewId;

  @override
  State<ProviderReviewScreen> createState() => _ProviderReviewScreenState();
}

class _ProviderReviewScreenState extends State<ProviderReviewScreen> {
  final _reply = TextEditingController();
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _reply.addListener(() => setState(() {}));
    WidgetsBinding.instance.addPostFrameCallback((_) => _ensureLoaded());
  }

  @override
  void dispose() {
    _reply.dispose();
    super.dispose();
  }

  /// A notice opened from outside the portal reads his reviews first.
  Future<void> _ensureLoaded() async {
    final dashboard = context.read<ProviderDashboardProvider>();
    if (_find(dashboard) != null || dashboard.isLoading) return;
    setState(() => _loading = true);
    await dashboard.loadDashboard();
    if (mounted) setState(() => _loading = false);
  }

  ProviderReview? _find(ProviderDashboardProvider dashboard) {
    for (final review in dashboard.reviews) {
      if (review.id == widget.reviewId) return review;
    }
    return null;
  }

  Future<void> _publish(ProviderDashboardProvider dashboard) async {
    final ok = await dashboard.replyToReview(widget.reviewId, _reply.text);
    if (!mounted) return;
    if (ok) {
      AarastToast.showSuccess(context, 'نشرنا ردك، ويشوفه الكل تحت التقييم.');
    } else {
      AarastToast.showError(
        context,
        dashboard.errorMessage ?? 'ما قدرنا ننشر ردك. حاول مرة ثانية.',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final dashboard = context.watch<ProviderDashboardProvider>();
    final review = _find(dashboard);
    final reply = review?.reply;
    return AarastScreenFrame(
      maxWidth: 520,
      backgroundColor: AarastV3Color.canvas,
      child: ListView(
        padding: AarastV3Density.pageInsets,
        children: [
          JourneySubHeader(title: reply == null ? 'تقييم جديد' : 'التقييم'),
          if (review == null)
            JourneyListState(
              phase: _loading || dashboard.isLoading
                  ? JourneyListPhase.loading
                  : JourneyListPhase.empty,
              section: JourneySection.home,
              emptyIcon: LucideIcons.star,
              emptyTitle: 'ما لقينا التقييم',
              emptyMessage: 'يمكن انحذف أو أخفاه فريق اعّرست.',
              onRetry: _ensureLoaded,
            )
          else ...[
            ProviderReviewCard(review: review),
            if (review.isPublished)
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: JourneyTextAction(
                  key: const Key('provider-review-report'),
                  label: 'فيه كلام مسيء أو كذب؟ بلّغ عنه',
                  icon: LucideIcons.flag,
                  color: AarastV3Color.textMuted,
                  // RA-ST-05 (D94): the review stays until the team decides.
                  onPressed: () => reportProviderReview(context, review.id),
                ),
              ),
            const SizedBox(height: AarastV3Space.x3),
            if (reply != null)
              ProviderReviewReplyBox(reply: reply)
            else if (!review.isPublished)
              const JourneyNote(
                key: Key('provider-review-hidden'),
                icon: LucideIcons.eyeOff,
                text: 'هذا التقييم ما يظهر للعرسان، فما يحتاج رد.',
              )
            else ...[
              JourneyTextField(
                key: const Key('provider-review-reply-field'),
                label: 'ردك (مرة وحدة، يشوفه الكل)',
                controller: _reply,
                minLines: 2,
                maxLines: 6,
                maxLength: 1000,
              ),
              const SizedBox(height: AarastV3Space.x3),
              JourneyButton(
                key: const Key('provider-review-reply-publish'),
                label: 'انشر الرد',
                expand: true,
                large: true,
                loading: dashboard.isSubmitting,
                onPressed: _reply.text.trim().isEmpty || dashboard.isSubmitting
                    ? null
                    : () => _publish(dashboard),
              ),
            ],
          ],
        ],
      ),
    );
  }
}
