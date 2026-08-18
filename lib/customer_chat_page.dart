import 'package:flutter/material.dart';

class CustomerChatPage extends StatefulWidget {
  const CustomerChatPage({super.key});

  @override
  State<CustomerChatPage> createState() =>
      _CustomerChatPageState();
}

class _CustomerChatPageState
    extends State<CustomerChatPage> {
  final TextEditingController messageController =
      TextEditingController();

  final ScrollController scrollController =
      ScrollController();

  final List<Map<String, dynamic>> messages = [
    {
      'message':
          'Hello! Welcome to RD Online Shop Support ',
      'isMe': false,
      'time': 'Now',
      'read': true,
      'type': 'text',
    },
    {
      'message':
          'How can we help you today?',
      'isMe': false,
      'time': 'Now',
      'read': true,
      'type': 'text',
    },
  ];

  // ==========================================
  // SEND MESSAGE
  // ==========================================

  void sendMessage() {
    final message =
        messageController.text.trim();

    if (message.isEmpty) {
      return;
    }

    final now = TimeOfDay.now();

    setState(() {
      messages.add({
        'message': message,
        'isMe': true,
        'time': now.format(context),
        'read': false,
        'type': 'text',
      });
    });

    messageController.clear();

    _scrollToBottom();

    Future.delayed(
      const Duration(seconds: 2),
      () {
        if (!mounted) {
          return;
        }

        setState(() {
          if (messages.isNotEmpty) {
            messages.last['read'] = true;
          }
        });
      },
    );
  }

  // ==========================================
  // VOICE MESSAGE
  // ==========================================

  void sendVoiceMessage() {
    setState(() {
      messages.add({
        'message': 'Voice message',
        'isMe': true,
        'time':
            TimeOfDay.now().format(context),
        'read': false,
        'type': 'voice',
      });
    });

    _scrollToBottom();

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Voice message added',
        ),
      ),
    );
  }

  // ==========================================
  // VOICE CALL
  // ==========================================

  void startVoiceCall() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape:
              RoundedRectangleBorder(
            borderRadius:
                BorderRadius.circular(20),
          ),
          title: const Row(
            children: [
              Icon(
                Icons.phone,
                color: Colors.green,
              ),
              SizedBox(width: 10),
              Text('Voice Call'),
            ],
          ),
          content: const Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircleAvatar(
                radius: 35,
                child: Icon(
                  Icons.support_agent,
                  size: 40,
                ),
              ),
              SizedBox(height: 15),
              Text(
                'RD Online Shop Support',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight:
                      FontWeight.bold,
                ),
              ),
              SizedBox(height: 8),
              Text(
                'Voice calling service will be connected here.',
                textAlign:
                    TextAlign.center,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: const Text(
                'Cancel',
              ),
            ),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.pop(context);

                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'Voice calling is ready for backend connection.',
                    ),
                  ),
                );
              },
              icon: const Icon(
                Icons.phone,
              ),
              label: const Text(
                'Call',
              ),
            ),
          ],
        );
      },
    );
  }

  // ==========================================
  // SCROLL TO BOTTOM
  // ==========================================

  void _scrollToBottom() {
    Future.delayed(
      const Duration(
        milliseconds: 100,
      ),
      () {
        if (!scrollController.hasClients) {
          return;
        }

        scrollController.animateTo(
          scrollController
              .position
              .maxScrollExtent,
          duration:
              const Duration(
            milliseconds: 300,
          ),
          curve: Curves.easeOut,
        );
      },
    );
  }

  // ==========================================
  // DISPOSE
  // ==========================================

  @override
  void dispose() {
    messageController.dispose();
    scrollController.dispose();

    super.dispose();
  }

  // ==========================================
  // BUILD
  // ==========================================

  @override
  Widget build(
    BuildContext context,
  ) {
    return Scaffold(
      backgroundColor:
          const Color(0xfff5f7fb),

      // ========================================
      // APP BAR
      // ========================================

      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 1,

        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back,
            color: Colors.black,
          ),
          onPressed: () {
            Navigator.pop(context);
          },
        ),

        title: const Row(
          children: [
            CircleAvatar(
              radius: 20,
              child: Icon(
                Icons.support_agent,
              ),
            ),
            SizedBox(width: 10),
            Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(
                  'RD Support',
                  style: TextStyle(
                    color: Colors.black,
                    fontSize: 17,
                    fontWeight:
                        FontWeight.bold,
                  ),
                ),
                Text(
                  'Online Support',
                  style: TextStyle(
                    color: Colors.green,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ],
        ),

        actions: [
          IconButton(
            onPressed: startVoiceCall,
            icon: const Icon(
              Icons.call,
              color: Colors.green,
            ),
            tooltip: 'Voice Call',
          ),
        ],
      ),

      // ========================================
      // BODY
      // ========================================

      body: Column(
        children: [

          // SUPPORT INFO

          Container(
            width: double.infinity,
            padding:
                const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 10,
            ),
            color: Colors.blue.shade50,

            child: const Row(
              children: [
                Icon(
                  Icons.info_outline,
                  size: 20,
                  color: Colors.blue,
                ),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Need help with your order? Chat with RD Support.',
                    style: TextStyle(
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ====================================
          // MESSAGES
          // ====================================

          Expanded(
            child: ListView.builder(
              controller:
                  scrollController,

              padding:
                  const EdgeInsets.all(14),

              itemCount:
                  messages.length,

              itemBuilder:
                  (context, index) {
                final message =
                    messages[index];

                final bool isMe =
                    message['isMe'] as bool;

                final String type =
                    message['type']
                        .toString();

                return _buildMessage(
                  message,
                  isMe,
                  type,
                );
              },
            ),
          ),

          // ====================================
          // INPUT AREA
          // ====================================

          SafeArea(
            child: Container(
              padding:
                  const EdgeInsets.all(8),

              decoration:
                  const BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    blurRadius: 5,
                    color: Colors.black12,
                  ),
                ],
              ),

              child: Row(
                children: [

                  // VOICE MESSAGE

                  IconButton(
                    onPressed:
                        sendVoiceMessage,
                    icon: const Icon(
                      Icons.mic,
                      color: Colors.red,
                    ),
                    tooltip:
                        'Voice Message',
                  ),

                  // TEXT BOX

                  Expanded(
                    child: TextField(
                      controller:
                          messageController,

                      textInputAction:
                          TextInputAction.send,

                      onSubmitted: (_) {
                        sendMessage();
                      },

                      minLines: 1,
                      maxLines: 4,

                      decoration:
                          InputDecoration(
                        hintText:
                            'Type your message...',

                        filled: true,

                        fillColor:
                            Colors.grey.shade100,

                        contentPadding:
                            const EdgeInsets
                                .symmetric(
                          horizontal: 18,
                          vertical: 12,
                        ),

                        border:
                            OutlineInputBorder(
                          borderRadius:
                              BorderRadius
                                  .circular(25),
                          borderSide:
                              BorderSide.none,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(
                    width: 6,
                  ),

                  // SEND

                  CircleAvatar(
                    radius: 24,
                    backgroundColor:
                        Colors.blue,

                    child: IconButton(
                      onPressed:
                          sendMessage,

                      icon: const Icon(
                        Icons.send,
                        color: Colors.white,
                        size: 21,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // MESSAGE WIDGET
  // ==========================================

  Widget _buildMessage(
    Map<String, dynamic> message,
    bool isMe,
    String type,
  ) {
    final String time =
        message['time']?.toString() ?? '';

    final bool read =
        message['read'] == true;

    return Align(
      alignment: isMe
          ? Alignment.centerRight
          : Alignment.centerLeft,

      child: Container(
        margin:
            const EdgeInsets.only(
          bottom: 10,
        ),

        padding:
            const EdgeInsets.symmetric(
          horizontal: 15,
          vertical: 10,
        ),

        constraints:
            BoxConstraints(
          maxWidth:
              MediaQuery.of(context)
                      .size
                      .width *
                  0.78,
        ),

        decoration:
            BoxDecoration(
          color: isMe
              ? Colors.blue
              : Colors.white,

          borderRadius:
              BorderRadius.only(
            topLeft:
                const Radius.circular(18),
            topRight:
                const Radius.circular(18),
            bottomLeft:
                Radius.circular(
              isMe ? 18 : 3,
            ),
            bottomRight:
                Radius.circular(
              isMe ? 3 : 18,
            ),
          ),

          boxShadow: [
            BoxShadow(
              color: Colors.black
                  .withValues(alpha: 0.05),
              blurRadius: 4,
            ),
          ],
        ),

        child: type == 'voice'
            ? _voiceMessage(
                isMe,
                time,
                read,
              )
            : _textMessage(
                message,
                isMe,
                time,
                read,
              ),
      ),
    );
  }

  // ==========================================
  // TEXT MESSAGE
  // ==========================================

  Widget _textMessage(
    Map<String, dynamic> message,
    bool isMe,
    String time,
    bool read,
  ) {
    return Column(
      crossAxisAlignment:
          CrossAxisAlignment.end,

      children: [
        Align(
          alignment:
              Alignment.centerLeft,

          child: Text(
            message['message']
                .toString(),

            style: TextStyle(
              color: isMe
                  ? Colors.white
                  : Colors.black87,
              fontSize: 15,
            ),
          ),
        ),

        const SizedBox(height: 4),

        Row(
          mainAxisSize:
              MainAxisSize.min,

          children: [
            Text(
              time,
              style: TextStyle(
                color: isMe
                    ? Colors.white70
                    : Colors.grey,
                fontSize: 10,
              ),
            ),

            if (isMe) ...[
              const SizedBox(
                width: 4,
              ),

              Icon(
                read
                    ? Icons.done_all
                    : Icons.done,
                size: 15,
                color: read
                    ? Colors.white
                    : Colors.white70,
              ),
            ],
          ],
        ),
      ],
    );
  }

  // ==========================================
  // VOICE MESSAGE
  // ==========================================

  Widget _voiceMessage(
    bool isMe,
    String time,
    bool read,
  ) {
    return Row(
      mainAxisSize:
          MainAxisSize.min,

      children: [
        CircleAvatar(
          radius: 20,

          backgroundColor:
              isMe
                  ? Colors.white24
                  : Colors.blue.shade50,

          child: Icon(
            Icons.play_arrow,
            color: isMe
                ? Colors.white
                : Colors.blue,
          ),
        ),

        const SizedBox(
          width: 10,
        ),

        SizedBox(
          width: 90,

          child: Row(
            children:
                List.generate(
              12,
              (index) {
                return Expanded(
                  child: Container(
                    margin:
                        const EdgeInsets
                            .symmetric(
                      horizontal: 1,
                    ),

                    height:
                        index % 3 == 0
                            ? 18
                            : 8,

                    decoration:
                        BoxDecoration(
                      color: isMe
                          ? Colors.white70
                          : Colors.blue,

                      borderRadius:
                          BorderRadius
                              .circular(5),
                    ),
                  ),
                );
              },
            ),
          ),
        ),

        const SizedBox(
          width: 8,
        ),

        Column(
          children: [
            Text(
              time,
              style: TextStyle(
                color: isMe
                    ? Colors.white70
                    : Colors.grey,
                fontSize: 10,
              ),
            ),

            if (isMe)
              Icon(
                read
                    ? Icons.done_all
                    : Icons.done,
                size: 14,
                color: Colors.white,
              ),
          ],
        ),
      ],
    );
  }
}