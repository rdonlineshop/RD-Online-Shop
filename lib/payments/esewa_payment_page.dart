import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import 'esewa_payment_service.dart';
import '../services/platform_capabilities.dart';

class EsewaPaymentPage extends StatefulWidget {
  final String transactionUuid;
  final double totalAmount;

  const EsewaPaymentPage({
    super.key,
    required this.transactionUuid,
    required this.totalAmount,
  });

  @override
  State<EsewaPaymentPage> createState() => _EsewaPaymentPageState();
}

class _EsewaPaymentPageState extends State<EsewaPaymentPage> {
  WebViewController? _controller;
  bool _loading = true;
  bool _verifying = false;
  bool _finished = false;

  @override
  void initState() {
    super.initState();

    if (!PlatformCapabilities.supportsEmbeddedWebView) {
      _loading = false;
      return;
    }

    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (_) {
            if (mounted && !_verifying) {
              setState(() => _loading = true);
            }
          },
          onPageFinished: (_) {
            if (mounted && !_verifying) {
              setState(() => _loading = false);
            }
          },
          onNavigationRequest: _handleNavigation,
        ),
      )
      ..loadHtmlString(
        EsewaPaymentService.createAutoSubmitHtml(
          transactionUuid: widget.transactionUuid,
          totalAmount: widget.totalAmount,
        ),
      );
  }

  Future<NavigationDecision> _handleNavigation(
    NavigationRequest request,
  ) async {
    if (request.url.startsWith(EsewaConfig.successUrl)) {
      if (!_finished) {
        _finished = true;
        await _handleSuccess(Uri.parse(request.url));
      }
      return NavigationDecision.prevent;
    }

    if (request.url.startsWith(EsewaConfig.failureUrl)) {
      if (!_finished && mounted) {
        _finished = true;
        Navigator.pop(
          context,
          EsewaResult.failure(
            transactionUuid: widget.transactionUuid,
            message: 'eSewa payment was not completed.',
          ),
        );
      }
      return NavigationDecision.prevent;
    }

    return NavigationDecision.navigate;
  }

  Future<void> _handleSuccess(Uri uri) async {
    if (!mounted) return;

    setState(() {
      _loading = false;
      _verifying = true;
    });

    final Map<String, dynamic>? callback =
        EsewaPaymentService.decodeCallback(uri);

    if (callback == null) {
      _finishFailure('Could not read the eSewa success response.');
      return;
    }

    final String status =
        callback['status']?.toString().trim().toUpperCase() ?? '';
    final String uuid =
        callback['transaction_uuid']?.toString().trim() ?? '';
    final String transactionCode =
        callback['transaction_code']?.toString().trim() ?? '';

    if (status != 'COMPLETE' || uuid != widget.transactionUuid) {
      _finishFailure('eSewa returned an invalid transaction response.');
      return;
    }

    if (!EsewaPaymentService.verifyCallbackSignature(callback)) {
      _finishFailure('eSewa response signature verification failed.');
      return;
    }

    final EsewaResult result =
        await EsewaPaymentService.verifyStatus(
      transactionUuid: widget.transactionUuid,
      totalAmount: widget.totalAmount,
      transactionCode: transactionCode,
    );

    if (mounted) {
      Navigator.pop(context, result);
    }
  }

  void _finishFailure(String message) {
    if (!mounted) return;

    Navigator.pop(
      context,
      EsewaResult.failure(
        transactionUuid: widget.transactionUuid,
        status: 'VERIFY_ERROR',
        message: message,
      ),
    );
  }

  Future<void> _cancel() async {
    if (_verifying) return;

    final bool? cancel = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Cancel eSewa Payment?'),
          content: const Text(
            'The order will not be marked as paid unless eSewa payment is verified.',
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Continue Payment'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Cancel'),
            ),
          ],
        );
      },
    );

    if (cancel == true && mounted) {
      _finished = true;
      Navigator.pop(
        context,
        EsewaResult.cancelled(widget.transactionUuid),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!PlatformCapabilities.supportsEmbeddedWebView) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('eSewa Payment - UAT'),
        ),
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  const Icon(
                    Icons.desktop_windows_outlined,
                    size: 64,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Embedded eSewa payment is not available on Windows.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Use RD Online Shop on Android, iPhone/iPad, or macOS for '
                    'the embedded payment screen. Cash on Delivery remains '
                    'available on Windows.',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),
                  FilledButton.icon(
                    onPressed: () {
                      Navigator.pop(
                        context,
                        EsewaResult.cancelled(widget.transactionUuid),
                      );
                    },
                    icon: const Icon(Icons.arrow_back),
                    label: const Text('Back to Checkout'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    final WebViewController? controller = _controller;

    if (controller == null) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, Object? result) async {
        if (!didPop) {
          await _cancel();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('eSewa Payment - UAT'),
          centerTitle: true,
          leading: IconButton(
            onPressed: _verifying ? null : _cancel,
            icon: const Icon(Icons.close),
          ),
        ),
        body: Stack(
          children: <Widget>[
            WebViewWidget(controller: controller),
            if (_loading || _verifying)
              const ColoredBox(
                color: Colors.white,
                child: Center(child: CircularProgressIndicator()),
              ),
            if (_verifying)
              const Align(
                alignment: Alignment.center,
                child: Padding(
                  padding: EdgeInsets.only(top: 90),
                  child: Text('Verifying eSewa payment...'),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
