import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';

class RideDriverAgreementAcceptance {
  const RideDriverAgreementAcceptance({
    required this.version,
    required this.acceptedName,
    required this.textHash,
    required this.textSnapshot,
  });

  final String version;
  final String acceptedName;
  final String textHash;
  final String textSnapshot;
}

class RideDriverAgreementText {
  const RideDriverAgreementText._();

  static const String title = 'RD Ride Driver Agreement';
  static const String version = 'RD-RIDE-DRIVER-1.0';

  static const String fullText = '''
RD RIDE DRIVER AGREEMENT
Version: RD-RIDE-DRIVER-1.0

IMPORTANT
This is the operating agreement between the Ride Driver and RD Ride platform. It is not a government licence, permit, or legal certification. The driver must independently follow all laws, transport rules, traffic rules, insurance requirements, permits, and official requirements that apply in the place where the ride is provided.

ENGLISH

1. Driver identity and truthful information
I confirm that the name, phone number, email, vehicle information, driving licence information, photographs, and other information I submit are true, current, and belong to me or are lawfully under my control. I will promptly update RD Ride if important information changes.

2. Valid licence, vehicle documents, and legal eligibility
I will drive only while I hold a valid driving licence and while the vehicle is legally permitted, registered, roadworthy, insured, and otherwise compliant where required by applicable law. I will not use another person's documents or false documents.

3. Safety and traffic compliance
I will obey applicable traffic and road-safety rules, use reasonable care, avoid dangerous driving, and take appropriate safety measures for the passenger, other road users, and myself. I will not drive while impaired by alcohol, drugs, extreme fatigue, or any condition that makes driving unsafe.

4. Customer service and respectful conduct
I will treat customers respectfully and without harassment, threats, discrimination, abuse, or intimidation. I will make a reasonable effort to provide the accepted ride safely and professionally and will communicate clearly if a delay or problem occurs.

5. Online availability and customer calls
When I intentionally set myself Online in RD Ride, I understand that customers may send ride requests and may be shown the driver contact number for ride-related communication. If I am available and it is safe to respond, I will make a reasonable effort to answer or return a customer's ride-related call, including at night. This does not require me to accept a ride when I am unavailable, unsafe, unwell, off duty, or legally unable to drive.

6. Customer contact privacy
I will use a customer's phone number, location, chat, and other personal information only for the ride, safety, support, payment, complaint, or other legitimate RD Ride purpose. I will not misuse, sell, publish, retain for unrelated purposes, spam, threaten, or harass a customer using their contact information.

7. Fare, RD commission, and seven-day payment obligation
I understand that the ride fare, RD commission, driver income, cancellation fee, and other amounts may be calculated according to the settings shown in RD Ride for that ride. Where RD Ride records an RD commission or other amount as payable by me, I agree to settle the due amount within 7 calendar days from the date it becomes due, unless RD Ride displays a different written due date. Unpaid due amounts may cause temporary account suspension and review until payment is verified.

8. Cancellations and no-show conduct
I will not repeatedly accept rides and cancel without a genuine reason. When cancellation is necessary, I will choose or provide the truthful reason requested by RD Ride. I understand that cancellation records may be visible to the customer and Admin and may be reviewed for safety, quality, fraud prevention, or account action.

9. No platform abuse or commission avoidance
I will not manipulate GPS, ride distance, fare, payment records, identity, ratings, documents, or account status. I will not intentionally move an RD Ride booking off-platform for the purpose of avoiding recorded RD commission, safety records, or platform controls.

10. GPS, location, and trip records
When Online or during an active ride, RD Ride may use my device location and ride-related data for nearby-driver discovery, pickup, navigation, live tracking, fare calculation, safety, support, dispute handling, and platform operations. I will not deliberately send false GPS information.

11. Accidents, emergencies, and safety incidents
If an accident, medical emergency, crime, serious safety issue, or other major incident occurs, I will first take reasonable emergency steps and contact the appropriate emergency or public authority when required. I will cooperate with legitimate RD Ride safety or complaint review and provide relevant truthful information.

12. Complaints, evidence, and investigation
I understand that ride, cancellation, contact, GPS, chat, payment, and account records may be reviewed by authorized RD Ride Admin personnel for complaint resolution, fraud prevention, safety, settlement, and enforcement, subject to applicable privacy and legal requirements.

13. Suspension, restriction, and termination
RD Ride may restrict, suspend, or terminate driver access for reasons including invalid or expired documents, safety risk, fraud, serious customer complaints, repeated misuse, unpaid amounts, policy violations, or legal requirements. Where the app provides an appeal, reactivation, or payment-review process, I may use that process.

14. Agreement updates
RD Ride may issue a new agreement version when rules or services change. If RD Ride marks re-acceptance as required, I must review and accept the new version before continuing the affected driver service.

15. Applicable law prevails
This agreement supplements, and does not replace or override, applicable law, government requirements, transport rules, traffic rules, court orders, or lawful directions of competent authorities. If a clause conflicts with mandatory law, the mandatory law prevails.

NEPALI / नेपाली

१. चालकको पहिचान र सही विवरण
मैले दिएको नाम, फोन नम्बर, इमेल, सवारी विवरण, ड्राइभिङ लाइसेन्स विवरण, फोटो तथा अन्य जानकारी सही, हालको र मेरो आफ्नै वा कानुनी रूपमा मेरो नियन्त्रणमा रहेको हो भन्ने म स्वीकार गर्छु। महत्वपूर्ण विवरण परिवर्तन भएमा RD Ride लाई अद्यावधिक गर्नेछु।

२. वैध लाइसेन्स, सवारी कागजात र कानुनी योग्यता
लागू कानूनअनुसार आवश्यक पर्ने वैध ड्राइभिङ लाइसेन्स, दर्ता, बीमा, सवारीको फिटनेस, परमिट वा अन्य कानुनी आवश्यकता पूरा भएको अवस्थामा मात्र सवारी चलाउनेछु। अरूको वा झुट्टा कागजात प्रयोग गर्नेछैन।

३. सुरक्षा र ट्राफिक नियम
लागू ट्राफिक तथा सडक सुरक्षा नियम पालना गर्नेछु, यात्रु, अन्य सडक प्रयोगकर्ता र आफ्नो सुरक्षामा उचित सावधानी अपनाउनेछु। मदिरा, लागू पदार्थ, अत्यधिक थकान वा सुरक्षित रूपमा सवारी चलाउन नसक्ने अवस्थामा ड्राइभ गर्नेछैन।

४. ग्राहकसँग सम्मानजनक व्यवहार
ग्राहकलाई सम्मानपूर्वक व्यवहार गर्नेछु। दुर्व्यवहार, धम्की, भेदभाव, हैरानी वा डर देखाउने काम गर्नेछैन। स्वीकार गरेको राइड सुरक्षित र व्यावसायिक रूपमा पूरा गर्न उचित प्रयास गर्नेछु र ढिलाइ वा समस्या भए स्पष्ट जानकारी दिनेछु।

५. Online अवस्था र ग्राहकको फोन
मैले RD Ride मा आफूलाई जानाजानी Online राखेको अवस्थामा ग्राहकले राइड request पठाउन र राइडसम्बन्धी सम्पर्कका लागि चालकको फोन नम्बर देख्न सक्ने कुरा बुझ्छु। म उपलब्ध छु र फोन उठाउन सुरक्षित छ भने, रातिको समयमा समेत, ग्राहकको राइडसम्बन्धी फोन उठाउन वा फिर्ता फोन गर्न उचित प्रयास गर्नेछु। तर म उपलब्ध नभएको, असुरक्षित, बिरामी, duty बाहिर वा कानुनी रूपमा सवारी चलाउन नसक्ने अवस्थामा राइड स्वीकार गर्न बाध्य हुने छैन।

६. ग्राहकको सम्पर्क गोपनीयता
ग्राहकको फोन नम्बर, location, chat वा व्यक्तिगत जानकारी राइड, सुरक्षा, support, payment, complaint वा वैध RD Ride प्रयोजनका लागि मात्र प्रयोग गर्नेछु। ग्राहकको जानकारी बेच्ने, सार्वजनिक गर्ने, असम्बन्धित प्रयोजनमा राख्ने, spam गर्ने, धम्की दिने वा हैरानी गर्ने काम गर्नेछैन।

७. भाडा, RD commission र ७ दिनभित्र भुक्तानी
राइडको fare, RD commission, driver income, cancellation fee तथा अन्य रकम सम्बन्धित ride मा देखाइएको RD Ride setting अनुसार गणना हुन सक्ने कुरा बुझ्छु। RD Ride ले मबाट तिर्नुपर्ने RD commission वा अन्य रकम due देखाएको अवस्थामा, app मा फरक लिखित due date नदिइएसम्म, due भएको मितिबाट ७ calendar दिनभित्र रकम बुझाउनेछु। समयमै नतिरेमा payment verify नभएसम्म account अस्थायी रूपमा suspend वा review हुन सक्ने कुरा स्वीकार गर्छु।

८. Cancellation र no-show व्यवहार
वास्तविक कारण बिना बारम्बार ride accept गरेर cancel गर्नेछैन। Cancellation आवश्यक भए RD Ride ले मागेको सही reason दिनेछु। Cancellation record ग्राहक र Admin लाई देखिन सक्ने र safety, quality, fraud prevention वा account action का लागि review हुन सक्ने कुरा बुझ्छु।

९. Platform दुरुपयोग वा commission छल्ने काम नगर्ने
GPS, दूरी, fare, payment record, identity, rating, documents वा account status गलत तरिकाले परिवर्तन वा manipulate गर्नेछैन। RD commission, safety record वा platform control छल्न RD Ride booking लाई जानाजानी बाहिर लैजानेछैन।

१०. GPS, location र trip record
Online हुँदा वा active ride चल्दा RD Ride ले nearby-driver search, pickup, navigation, live tracking, fare calculation, safety, support, dispute handling र platform operation का लागि device location तथा ride-related data प्रयोग गर्न सक्ने कुरा स्वीकार गर्छु। जानाजानी गलत GPS पठाउनेछैन।

११. दुर्घटना, emergency र safety incident
दुर्घटना, medical emergency, अपराध, गम्भीर safety problem वा ठूलो incident भएमा पहिले उचित emergency कदम चाल्नेछु र आवश्यक परे सम्बन्धित emergency service वा सरकारी निकायलाई सम्पर्क गर्नेछु। RD Ride को वैध safety/complaint review मा सत्य विवरणसहित सहयोग गर्नेछु।

१२. Complaint, evidence र investigation
Complaint समाधान, fraud prevention, safety, settlement र नियम पालना गराउन अधिकृत RD Ride Admin ले ride, cancellation, contact, GPS, chat, payment र account record लागू privacy तथा कानुनी आवश्यकताअनुसार review गर्न सक्ने कुरा बुझ्छु।

१३. Suspension, restriction र termination
Invalid/expired documents, safety risk, fraud, गम्भीर customer complaint, repeated misuse, unpaid amount, policy violation वा कानुनी कारणले RD Ride ले driver access restrict, suspend वा terminate गर्न सक्ने कुरा स्वीकार गर्छु। App मा appeal, reactivation वा payment review process भए म त्यही process प्रयोग गर्न सक्छु।

१४. Agreement update
नियम वा service परिवर्तन भए RD Ride ले नयाँ agreement version जारी गर्न सक्छ। Re-acceptance required देखाइएमा सम्बन्धित driver service जारी राख्न नयाँ version पढेर स्वीकार गर्नुपर्नेछ।

१५. लागू कानून प्राथमिक हुन्छ
यो agreement लागू कानून, सरकारी मापदण्ड, transport/traffic rule, अदालतको आदेश वा सक्षम निकायको वैध निर्देशनको विकल्प होइन। कुनै clause अनिवार्य कानूनसँग बाझिएमा अनिवार्य कानून नै लागू हुनेछ।
''';

  static String get textHash =>
      sha256.convert(utf8.encode(fullText)).toString();
}

class RideDriverAgreementPage extends StatefulWidget {
  const RideDriverAgreementPage({
    required this.driverName,
    this.reviewOnly = false,
    this.acceptedName = '',
    this.acceptedVersion = '',
    this.acceptedHash = '',
    this.acceptedAtText = '',
    this.agreementText = '',
    super.key,
  });

  final String driverName;
  final bool reviewOnly;
  final String acceptedName;
  final String acceptedVersion;
  final String acceptedHash;
  final String acceptedAtText;
  final String agreementText;

  @override
  State<RideDriverAgreementPage> createState() =>
      _RideDriverAgreementPageState();
}

class _RideDriverAgreementPageState
    extends State<RideDriverAgreementPage> {
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _nameController = TextEditingController();

  bool _readToEnd = false;
  bool _agreed = false;

  String get _shownText => widget.agreementText.trim().isEmpty
      ? RideDriverAgreementText.fullText
      : widget.agreementText;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_handleScroll);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) {
        return;
      }
      if (_scrollController.position.maxScrollExtent <= 12) {
        setState(() {
          _readToEnd = true;
        });
      }
    });
  }

  void _handleScroll() {
    if (_readToEnd || !_scrollController.hasClients) {
      return;
    }

    final ScrollPosition position = _scrollController.position;
    if (position.pixels >= position.maxScrollExtent - 24) {
      setState(() {
        _readToEnd = true;
      });
    }
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_handleScroll)
      ..dispose();
    _nameController.dispose();
    super.dispose();
  }

  bool get _nameMatches =>
      _nameController.text.trim().toLowerCase() ==
      widget.driverName.trim().toLowerCase();

  bool get _canAccept =>
      _readToEnd && _agreed && _nameMatches && widget.driverName.trim().isNotEmpty;

  void _accept() {
    if (!_canAccept) {
      return;
    }

    Navigator.pop<RideDriverAgreementAcceptance>(
      context,
      RideDriverAgreementAcceptance(
        version: RideDriverAgreementText.version,
        acceptedName: widget.driverName.trim(),
        textHash: RideDriverAgreementText.textHash,
        textSnapshot: RideDriverAgreementText.fullText,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final String calculatedHash =
        sha256.convert(utf8.encode(_shownText)).toString();
    final bool hashRecorded = widget.acceptedHash.trim().isNotEmpty;
    final bool integrityMatches =
        hashRecorded && widget.acceptedHash.trim() == calculatedHash;

    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      appBar: AppBar(
        title: const Text(
          'Driver Agreement',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 850),
            child: Column(
              children: <Widget>[
                if (widget.reviewOnly)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: <Widget>[
                            const Text(
                              'Acceptance Record',
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(height: 8),
                            _recordRow(
                              'Driver',
                              widget.acceptedName.trim().isEmpty
                                  ? widget.driverName
                                  : widget.acceptedName,
                            ),
                            _recordRow(
                              'Version',
                              widget.acceptedVersion.trim().isEmpty
                                  ? 'Not recorded'
                                  : widget.acceptedVersion,
                            ),
                            _recordRow(
                              'Accepted at',
                              widget.acceptedAtText.trim().isEmpty
                                  ? 'Not recorded'
                                  : widget.acceptedAtText,
                            ),
                            _recordRow(
                              'Integrity',
                              !hashRecorded
                                  ? 'Hash not recorded'
                                  : integrityMatches
                                      ? 'Hash matches saved agreement'
                                      : 'HASH MISMATCH — review required',
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                Expanded(
                  child: Card(
                    margin: const EdgeInsets.all(16),
                    child: Scrollbar(
                      controller: _scrollController,
                      thumbVisibility: true,
                      child: SingleChildScrollView(
                        controller: _scrollController,
                        padding: const EdgeInsets.all(18),
                        child: SelectableText(
                          _shownText.trim(),
                          style: const TextStyle(
                            fontSize: 14.5,
                            height: 1.52,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                if (!widget.reviewOnly)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surface,
                      border: Border(
                        top: BorderSide(color: Colors.grey.shade300),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        Row(
                          children: <Widget>[
                            Icon(
                              _readToEnd
                                  ? Icons.check_circle_rounded
                                  : Icons.south_rounded,
                              color: _readToEnd ? Colors.green : Colors.orange,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _readToEnd
                                    ? 'Agreement read to the end.'
                                    : 'Please scroll to the end before accepting.',
                                style: const TextStyle(fontWeight: FontWeight.w700),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        CheckboxListTile(
                          contentPadding: EdgeInsets.zero,
                          value: _agreed,
                          onChanged: _readToEnd
                              ? (bool? value) {
                                  setState(() {
                                    _agreed = value == true;
                                  });
                                }
                              : null,
                          title: const Text(
                            'I have read and agree to the RD Ride Driver Agreement.',
                            style: TextStyle(fontWeight: FontWeight.w800),
                          ),
                          controlAffinity: ListTileControlAffinity.leading,
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _nameController,
                          enabled: _readToEnd && _agreed,
                          textInputAction: TextInputAction.done,
                          onChanged: (_) => setState(() {}),
                          onSubmitted: (_) => _accept(),
                          decoration: InputDecoration(
                            labelText: 'Type your full name to confirm',
                            hintText: widget.driverName,
                            prefixIcon: const Icon(Icons.draw_rounded),
                            helperText: _nameController.text.trim().isEmpty || _nameMatches
                                ? 'Must match the registration name: ${widget.driverName}'
                                : 'Name does not match the registration name.',
                            helperStyle: TextStyle(
                              color: _nameController.text.trim().isNotEmpty && !_nameMatches
                                  ? Colors.red
                                  : null,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        FilledButton.icon(
                          onPressed: _canAccept ? _accept : null,
                          icon: const Icon(Icons.verified_user_rounded),
                          label: const Text(
                            'Accept Agreement & Submit Registration',
                            style: TextStyle(fontWeight: FontWeight.w900),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _recordRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: TextStyle(
                color: Colors.grey.shade700,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }
}
