import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

import '../../../core/network/api_exception.dart';
import '../models/merchant_payment_intent.dart';
import '../services/payment_intent_service.dart';
import '../widgets/merchant_brand_logo.dart';
import 'payment_intent_qr_screen.dart';

const _canvas = Color(0xFFFCF9F8);
const _ink = Color(0xFF222222);
const _supporting = Color(0xFF484848);
const _secondary = Color(0xFF767676);
const _divider = Color(0xFFEBEBEB);
const _electric = Color(0xFF0072DC);
const _fieldFill = Color(0xFFF7F7F7);

class CreatePaymentRequestScreen extends StatefulWidget {
  const CreatePaymentRequestScreen({super.key, this.paymentIntentService});

  final PaymentIntentService? paymentIntentService;

  @override
  State<CreatePaymentRequestScreen> createState() =>
      _CreatePaymentRequestScreenState();
}

class _CreatePaymentRequestScreenState
    extends State<CreatePaymentRequestScreen> {
  static final _amountPattern = RegExp(r'^\d+(?:\.\d{1,2})?$');
  static final _safeMinorUnitLimit = BigInt.parse('9007199254740991');

  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _descriptionController = TextEditingController();
  late final PaymentIntentService _paymentIntentService;
  bool _isSubmitting = false;
  String? _submissionError;

  @override
  void initState() {
    super.initState();
    _paymentIntentService =
        widget.paymentIntentService ?? ApiPaymentIntentService();
  }

  @override
  void dispose() {
    _amountController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  String? _validateAmount(String? value) {
    final amount = value?.trim() ?? '';
    if (amount.isEmpty) return 'Enter an amount.';
    if (amount.startsWith('-')) {
      return 'Amount must be greater than LKR 0.00.';
    }
    if (!_amountPattern.hasMatch(amount)) {
      return 'Enter a valid amount with up to two decimal places.';
    }

    final amountMinor = parseLkrAmountToMinorUnits(amount);
    if (amountMinor == null) return 'That amount is too large.';
    if (amountMinor <= 0) return 'Amount must be greater than LKR 0.00.';
    return null;
  }

  Future<void> _submit() async {
    if (_isSubmitting || !(_formKey.currentState?.validate() ?? false)) return;

    final amountMinor = parseLkrAmountToMinorUnits(_amountController.text);
    if (amountMinor == null || amountMinor <= 0) return;

    setState(() {
      _isSubmitting = true;
      _submissionError = null;
    });

    try {
      final intent = await _paymentIntentService.createPaymentIntent(
        amountMinor: amountMinor,
        description: _descriptionController.text.trim(),
      );

      if (!_isValidCreatedIntent(intent, amountMinor)) {
        throw const ApiException(
          200,
          'The server returned an invalid payment request. Please try again.',
        );
      }

      if (!mounted) return;
      final createNewRequest = await Navigator.of(context).push<bool>(
        MaterialPageRoute<bool>(
          builder: (_) => PaymentIntentQrScreen(
            paymentIntent: intent,
            paymentIntentService: _paymentIntentService,
          ),
        ),
      );
      if (createNewRequest == true && mounted) {
        _amountController.clear();
        _descriptionController.clear();
      }
    } catch (error) {
      if (mounted) setState(() => _submissionError = _friendlyError(error));
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  bool _isValidCreatedIntent(MerchantPaymentIntent intent, int amountMinor) {
    return intent.paymentReference.trim().isNotEmpty &&
        intent.merchantName.trim().isNotEmpty &&
        intent.amountMinor == amountMinor &&
        intent.currency == 'LKR' &&
        intent.status == 'PENDING' &&
        intent.expiresAt.isAfter(intent.createdAt) &&
        intent.expiresAt.isAfter(DateTime.now());
  }

  String _friendlyError(Object error) {
    if (error is ApiException) {
      return switch (error.statusCode) {
        400 => error.message,
        401 => 'Your session has expired. Please sign in again.',
        403 => 'This account cannot create merchant payment requests.',
        _ => error.message,
      };
    }
    if (error is SocketException ||
        error is http.ClientException ||
        error is TimeoutException) {
      return 'Unable to reach VPay. Check your connection and try again.';
    }
    if (error is StateError) {
      return 'Your session has expired. Please sign in again.';
    }
    return 'Unable to create the payment request. Please try again.';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _canvas,
      appBar: AppBar(
        backgroundColor: _canvas,
        foregroundColor: _ink,
        elevation: 0,
        centerTitle: false,
        titleSpacing: 0,
        toolbarHeight: 64,
        title: const Row(
          children: [
            MerchantBrandLogo(height: 22),
            SizedBox(width: 8),
            Flexible(
              child: Text(
                'Create Payment Request',
                maxLines: 2,
                softWrap: true,
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
      ),
      body: SafeArea(
        top: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
                children: [
                  _buildIntro(),
                  const SizedBox(height: 24),
                  _buildAmountField(),
                  const SizedBox(height: 18),
                  _buildDescriptionField(),
                  const SizedBox(height: 16),
                  _buildExpiryNote(),
                  if (_submissionError != null) ...[
                    const SizedBox(height: 16),
                    _buildErrorBanner(_submissionError!),
                  ],
                  const SizedBox(height: 24),
                  _buildSubmitButton(),
                  const SizedBox(height: 12),
                  const Text(
                    'Your customer will confirm this request in VPay.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: _secondary, fontSize: 12),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildIntro() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            color: _electric.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Icon(
            Icons.qr_code_2_rounded,
            color: _electric,
            size: 28,
          ),
        ),
        const SizedBox(height: 18),
        const Text(
          'Request a payment',
          style: TextStyle(
            color: _ink,
            fontSize: 26,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'Enter the amount and we’ll create a secure payment QR for your customer.',
          style: TextStyle(color: _supporting, fontSize: 14, height: 1.45),
        ),
      ],
    );
  }

  Widget _buildAmountField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Amount',
          style: TextStyle(
            color: _ink,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          key: const Key('paymentAmountField'),
          controller: _amountController,
          enabled: !_isSubmitting,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          textInputAction: TextInputAction.next,
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[0-9.\-]')),
          ],
          validator: _validateAmount,
          onChanged: (_) {
            if (_submissionError != null) {
              setState(() => _submissionError = null);
            }
          },
          style: const TextStyle(
            color: _ink,
            fontSize: 24,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.3,
          ),
          decoration: InputDecoration(
            hintText: '0.00',
            hintStyle: const TextStyle(color: Color(0xFFB0B0B0)),
            suffixText: 'LKR',
            suffixStyle: const TextStyle(
              color: _secondary,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
            filled: true,
            fillColor: _fieldFill,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 18,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: _divider),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: _electric),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFC74A4A)),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(
                color: Color(0xFFC74A4A),
                width: 1.5,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDescriptionField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Description',
          style: TextStyle(
            color: _ink,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          key: const Key('paymentDescriptionField'),
          controller: _descriptionController,
          enabled: !_isSubmitting,
          maxLength: 200,
          maxLines: 2,
          textInputAction: TextInputAction.done,
          decoration: InputDecoration(
            hintText: 'What is this payment for? (optional)',
            hintStyle: const TextStyle(color: Color(0xFF999999), fontSize: 14),
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.all(16),
            counterStyle: const TextStyle(color: _secondary, fontSize: 11),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: _divider),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: _divider),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: _electric),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildExpiryNote() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: _divider),
        borderRadius: BorderRadius.circular(14),
      ),
      child: const Row(
        children: [
          Icon(Icons.schedule_rounded, color: _electric, size: 20),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'This payment request expires in 15 minutes.',
              style: TextStyle(color: _supporting, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorBanner(String message) {
    return Container(
      key: const Key('paymentRequestError'),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF2F0),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFF2CBC5)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.error_outline_rounded, color: Color(0xFFC74A4A)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(color: Color(0xFF8B2E25), fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubmitButton() {
    return SizedBox(
      height: 52,
      child: FilledButton(
        key: const Key('createPaymentRequestButton'),
        onPressed: _isSubmitting ? null : _submit,
        style: FilledButton.styleFrom(
          backgroundColor: _electric,
          disabledBackgroundColor: _electric.withValues(alpha: 0.65),
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        child: _isSubmitting
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  key: Key('paymentRequestLoadingIndicator'),
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : const Text(
                'Generate Payment QR',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
              ),
      ),
    );
  }
}

int? parseLkrAmountToMinorUnits(String value) {
  final amount = value.trim();
  if (!_CreatePaymentRequestScreenState._amountPattern.hasMatch(amount)) {
    return null;
  }

  final parts = amount.split('.');
  final whole = BigInt.tryParse(parts.first);
  final fraction = BigInt.tryParse(
    (parts.length == 2 ? parts[1] : '').padRight(2, '0'),
  );
  if (whole == null || fraction == null) return null;

  final minorUnits = whole * BigInt.from(100) + fraction;
  if (minorUnits > _CreatePaymentRequestScreenState._safeMinorUnitLimit) {
    return null;
  }
  return minorUnits.toInt();
}
