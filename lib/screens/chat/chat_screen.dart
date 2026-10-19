import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/routes/app_router.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/screen_utils.dart';
import '../../data/models/chat_message.dart';
import '../../data/models/enums.dart';
import '../../providers/chat_provider.dart';
import '../../providers/notification_provider.dart';
import '../../providers/registration_provider.dart';
import '../../providers/request_provider.dart';
import '../../providers/session_provider.dart';
import '../../widgets/app_widgets.dart';

/// Real two-way chat between one resident and the shelter they live at.
/// Opened by the user (from the shelter profile) or by the shelter (from
/// its Chats tab); each side only ever sees its own thread.
class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key, required this.userId, required this.shelterId});

  final String userId;
  final String shelterId;

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _text = TextEditingController();
  final _scroll = ScrollController();
  final _focus = FocusNode();

  @override
  void dispose() {
    _text.dispose();
    _scroll.dispose();
    _focus.dispose();
    super.dispose();
  }

  bool get _adminThread => widget.userId == NotificationProvider.adminId;

  bool _asAdmin(SessionProvider s) =>
      s.persona == Persona.admin && _adminThread;

  bool _asShelter(SessionProvider s) =>
      s.persona == Persona.partner && s.activePartnerId == widget.shelterId;

  Future<void> _send(
    bool asShelter,
    String userName,
    String shelterName,
  ) async {
    final t = _text.text;
    if (t.trim().isEmpty) return;
    _text.clear();
    await context.read<ChatProvider>().send(
      userId: widget.userId,
      userName: userName,
      shelterId: widget.shelterId,
      shelterName: shelterName,
      fromUser: !asShelter,
      text: t,
    );
    if (_scroll.hasClients) _scroll.jumpTo(0);
    _focus.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionProvider>();
    final chat = context.watch<ChatProvider>();
    final regs = context.watch<RegistrationProvider>();
    final reqs = context.watch<RequestProvider>();
    final asShelter = _asShelter(session);

    // Only the two participants may open this thread.
    final allowed = asShelter || _asAdmin(session)
        ? true
        : (session.persona == Persona.needy &&
              session.deviceId == widget.userId);
    final shelter = regs.byId(widget.shelterId);
    final stay = reqs.chatStay(widget.userId);
    final userName = _adminThread
        ? 'Admin'
        : stay?.requesterName ??
              regs.individualOf(widget.userId)?.name ??
              'Resident';
    final shelterName = shelter?.displayName ?? 'Shelter';
    final open =
        _adminThread || (stay != null && stay.targetId == widget.shelterId);
    final msgs = chat.messages(widget.userId, widget.shelterId);

    if (allowed) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          context.read<ChatProvider>().markRead(
            widget.userId,
            widget.shelterId,
            asUser: !asShelter,
          );
        }
      });
    }

    return Scaffold(
      appBar: PreferredSize(
        preferredSize: Size.fromHeight(76.h),
        child: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [AppColors.primary, Color(0xFF134E4A)],
            ),
          ),
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: EdgeInsets.fromLTRB(4.w, 6.h, 16.w, 10.h),
              child: Row(
                children: [
                  IconButton(
                    color: Colors.white,
                    icon: const Icon(Icons.arrow_back_rounded),
                    onPressed: () => Navigator.maybePop(context),
                  ),
                  Container(
                    padding: EdgeInsets.all(2.r),
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                    child: CircleAvatar(
                      radius: 20.r,
                      backgroundColor: AppColors.primary.withValues(
                        alpha: 0.12,
                      ),
                      child: Icon(
                        asShelter
                            ? Icons.person_rounded
                            : Icons.home_work_rounded,
                        color: AppColors.primary,
                        size: 20.sp,
                      ),
                    ),
                  ),
                  SizedBox(width: 12.w),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          asShelter ? userName : shelterName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 17.sp,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Row(
                          children: [
                            Container(
                              width: 8.r,
                              height: 8.r,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: open
                                    ? const Color(0xFF4ADE80)
                                    : Colors.white54,
                              ),
                            ),
                            SizedBox(width: 6.w),
                            Expanded(
                              child: Text(
                                open
                                    ? (asShelter
                                          ? (_adminThread
                                                ? 'Admin'
                                                : 'Registered resident')
                                          : 'Your shelter${shelter == null ? '' : ' · ${shelter.city}'}')
                                    : 'Chat closed',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.85),
                                  fontSize: 12.5.sp,
                                ),
                              ),
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
        ),
      ),
      body: SafeArea(
        child: !allowed
            ? const EmptyState(
                icon: Icons.lock_outline_rounded,
                title: 'Private chat',
                message:
                    'Only the resident and their shelter can open this chat.',
              )
            : Column(
                children: [
                  Expanded(
                    child: msgs.isEmpty
                        ? EmptyState(
                            icon: Icons.chat_bubble_outline_rounded,
                            title: 'No messages yet',
                            message: open
                                ? 'Say hello to ${asShelter ? userName : shelterName}.'
                                : 'This chat is closed.',
                          )
                        : Align(
                            alignment: Alignment.topCenter,
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(
                                maxWidth: ScreenUtils.maxContentWidth,
                              ),
                              child: ListView.builder(
                                controller: _scroll,
                                reverse: true,
                                padding: EdgeInsets.fromLTRB(
                                  12.w,
                                  12.h,
                                  12.w,
                                  8.h,
                                ),
                                itemCount: msgs.length,
                                itemBuilder: (_, i) {
                                  final m = msgs[msgs.length - 1 - i];
                                  return _Bubble(
                                    message: m,
                                    mine: m.fromUser != asShelter,
                                  );
                                },
                              ),
                            ),
                          ),
                  ),
                  if (!open)
                    Container(
                      width: double.infinity,
                      color: AppColors.neutral.withValues(alpha: 0.1),
                      padding: EdgeInsets.all(12.r),
                      child: Text(
                        'You are no longer registered at this shelter, so new messages are disabled.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 12.5.sp,
                          color: AppColors.neutral,
                        ),
                      ),
                    )
                  else
                    Container(
                      padding: EdgeInsets.fromLTRB(12.w, 8.h, 8.w, 10.h),
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        border: Border(
                          top: BorderSide(color: Color(0xFFE2E8F0)),
                        ),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _text,
                              focusNode: _focus,
                              minLines: 1,
                              maxLines: 4,
                              // Plain text keyboard + send action so Enter
                              // sends instead of adding a new line.
                              keyboardType: TextInputType.text,
                              textInputAction: TextInputAction.send,
                              textCapitalization: TextCapitalization.sentences,
                              decoration: InputDecoration(
                                hintText: 'Type a message',
                                contentPadding: EdgeInsets.symmetric(
                                  horizontal: 16.w,
                                  vertical: 10.h,
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(26),
                                ),
                              ),
                              onSubmitted: (_) =>
                                  _send(asShelter, userName, shelterName),
                            ),
                          ),
                          SizedBox(width: 6.w),
                          IconButton.filled(
                            onPressed: () =>
                                _send(asShelter, userName, shelterName),
                            icon: const Icon(Icons.send_rounded),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.message, required this.mine});

  final ChatMessage message;
  final bool mine;

  @override
  Widget build(BuildContext context) {
    if (message.system) {
      return Padding(
        padding: EdgeInsets.symmetric(vertical: 6.h),
        child: Center(
          child: Container(
            constraints: BoxConstraints(maxWidth: 300.w),
            padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 8.h),
            decoration: BoxDecoration(
              color: AppColors.accent.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Text(
              message.text,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12.5.sp,
                color: const Color(0xFF78350F),
              ),
            ),
          ),
        ),
      );
    }
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(maxWidth: 280.w),
        margin: EdgeInsets.symmetric(vertical: 3.h),
        padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 9.h),
        decoration: BoxDecoration(
          color: mine ? AppColors.primary : Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(18),
            topRight: const Radius.circular(18),
            bottomLeft: Radius.circular(mine ? 18 : 4),
            bottomRight: Radius.circular(mine ? 4 : 18),
          ),
          border: mine ? null : Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              message.text,
              style: TextStyle(
                fontSize: 14.sp,
                height: 1.35,
                color: mine ? Colors.white : const Color(0xFF0F172A),
              ),
            ),
            SizedBox(height: 3.h),
            Text(
              fmtTime(message.createdAt),
              style: TextStyle(
                fontSize: 10.5.sp,
                color: mine ? Colors.white70 : AppColors.neutral,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Shelter inbox: one chat per resident.
class ShelterChatsTab extends StatelessWidget {
  const ShelterChatsTab({super.key, required this.shelterId});

  final String shelterId;

  @override
  Widget build(BuildContext context) {
    final chat = context.watch<ChatProvider>();
    final reqs = context.watch<RequestProvider>();
    final residents = reqs.chatPartnersOf(shelterId);
    final threads = chat.threadsOfShelter(shelterId);
    final byUser = {for (final t in threads) t.userId: t};

    // Residents first (newest message on top), then ended conversations.
    final ids = <String>[
      ...threads
          .map((t) => t.userId)
          .where((u) => residents.any((r) => r.requesterId == u)),
      ...residents
          .map((r) => r.requesterId)
          .where((u) => !byUser.containsKey(u)),
      ...threads
          .map((t) => t.userId)
          .where((u) => !residents.any((r) => r.requesterId == u)),
    ];
    if (threads.isEmpty) {
      return const EmptyState(
        icon: Icons.forum_outlined,
        title: 'No updates on chat yet',
        message:
            'No messages have arrived so far. When a resident writes to your shelter, the conversation will show up here.',
      );
    }
    String nameOf(String uid) {
      for (final r in residents) {
        if (r.requesterId == uid) return r.requesterName;
      }
      if (uid == NotificationProvider.adminId) return 'Admin';
      final last = reqs
          .sentBy(uid)
          .where((r) => r.targetId == shelterId)
          .firstOrNull;
      return last?.requesterName ?? 'Resident';
    }

    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          maxWidth: ScreenUtils.maxContentWidth,
        ),
        child: ListView.separated(
          padding: EdgeInsets.fromLTRB(16.w, 8.h, 16.w, 24.h),
          itemCount: ids.length,
          separatorBuilder: (_, _) => SizedBox(height: 10.h),
          itemBuilder: (_, i) {
            final uid = ids[i];
            final last = byUser[uid];
            final unread = chat.unreadForShelter(shelterId, uid);
            final isResident =
                uid == NotificationProvider.adminId ||
                residents.any((r) => r.requesterId == uid);
            return Card(
              child: ListTile(
                onTap: () =>
                    AppRouter.push(context, AppRoutes.chat, '$uid|$shelterId'),
                leading: CircleAvatar(
                  backgroundColor: AppColors.primary.withValues(alpha: 0.12),
                  child: Text(
                    nameOf(uid).isEmpty ? '?' : nameOf(uid)[0].toUpperCase(),
                    style: const TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                title: Text(
                  nameOf(uid),
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                subtitle: Text(
                  last == null
                      ? 'Tap to start chatting'
                      : '${last.fromUser ? '' : 'You: '}${last.text}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    if (last != null)
                      Text(
                        timeAgo(last.createdAt),
                        style: TextStyle(
                          fontSize: 11.sp,
                          color: AppColors.neutral,
                        ),
                      ),
                    if (unread > 0)
                      Badge(label: Text('$unread'))
                    else if (!isResident)
                      Text(
                        'closed',
                        style: TextStyle(
                          fontSize: 11.sp,
                          color: AppColors.neutral,
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
