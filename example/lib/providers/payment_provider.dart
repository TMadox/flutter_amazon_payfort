import 'package:amazon_payfort/amazon_payfort.dart';
import 'package:amazon_payfort_example/apis/payfort_api.dart';
import 'package:amazon_payfort_example/constants/fort_constants.dart';
import 'package:amazon_payfort_example/models/sdk_token_response.dart';
import 'package:amazon_payfort_example/providers/default_change_notifier.dart';
import 'package:network_info_plus/network_info_plus.dart';

class PaymentProvider extends DefaultChangeNotifier {
  final AmazonPayfort _payfort = AmazonPayfort.instance;

  final NetworkInfo _info = NetworkInfo();

  Future<void> init() async {
    /// Step 1:  Initialize Amazon Payfort
    await AmazonPayfort.initialize(
      const PayFortOptions(environment: FortConstants.environment),
    );
  }

  Future<void> paymentWithCreditOrDebitCard({
    required SucceededCallback onSucceeded,
    required FailedCallback onFailed,
    required CancelledCallback onCancelled,
  }) async {
    try {
      var sdkTokenResponse = await _generateSdkToken();

      /// Step 4: Processing Payment [Amount multiply with 100] ex. 10 * 100 = 1000 (10 SAR)
      FortRequest request = FortRequest(
        amount: 10 * 100,
        customerName: 'Test Customer',
        customerEmail: 'test@customer.com',
        orderDescription: 'Test Order',
        sdkToken: sdkTokenResponse?.sdkToken ?? '',
        merchantReference: 'Order ${DateTime.now().millisecondsSinceEpoch}',
        currency: 'SAR',
        customerIp: (await _info.getWifiIP() ?? ''),
      );

      _payfort.callPayFort(
        request: request,
        onSucceeded: onSucceeded,
        onFailed: onFailed,
        onCancelled: onCancelled,
      );
    } catch (e) {
      onFailed(e.toString());
    }
  }

  Future<void> paymentWithApplePay({
    required ApplePaySucceededCallback onSucceeded,
    required ApplePayFailedCallback onFailed,
  }) async {
    try {
      var sdkTokenResponse = await _generateSdkToken(isApplePay: true);

      /// Step 4: Processing Payment
      FortRequest request = FortRequest(
        amount: 10,
        customerName: 'Test Customer',
        customerEmail: 'test@customer.com',
        orderDescription: 'Test Order',
        sdkToken: sdkTokenResponse?.sdkToken ?? '',
        merchantReference: 'Order ${DateTime.now().millisecondsSinceEpoch}',
        currency: 'SAR',
        customerIp: (await _info.getWifiIP() ?? ''),
      );

      _payfort.callPayFortForApplePay(
        request: request,
        applePayMerchantId: FortConstants.applePayMerchantId,
        onSucceeded: onSucceeded,
        onFailed: onFailed,
      );
    } catch (e) {
      onFailed(e.toString());
    }
  }

  Future<SdkTokenResponse?> _generateSdkToken({bool isApplePay = false}) async {
    try {
      loading = true;

      var accessCode = isApplePay
          ? FortConstants.applePayAccessCode
          : FortConstants.accessCode;
      var shaRequestPhrase = isApplePay
          ? FortConstants.applePayShaRequestPhrase
          : FortConstants.shaRequestPhrase;
      String? deviceId = await _payfort.getDeviceId();

      /// Step 2:  Generate the Signature
      SdkTokenRequest tokenRequest = SdkTokenRequest(
        accessCode: accessCode,
        deviceId: deviceId ?? '',
        merchantIdentifier: FortConstants.merchantIdentifier,
      );

      String? signature = await _payfort.generateSignature(
        shaType: FortConstants.shaType,
        concatenatedString: tokenRequest.toConcatenatedString(shaRequestPhrase),
      );

      tokenRequest = tokenRequest.copyWith(signature: signature);

      /// Step 3: Generate the SDK Token
      return await PayFortApi.generateSdkToken(tokenRequest);
    } finally {
      loading = false;
    }
  }
}
