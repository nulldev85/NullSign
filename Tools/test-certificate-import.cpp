#include "certificate_validation.h"
#include "openssl.h"
#include <iostream>

int main(int argc, char** argv)
{
	if (argc < 5) return 2;
	const std::string mode = argv[1];
	if (mode == "old-check") {
		// Original import order, including the CMS-decode initialization workaround.
		BIO* profile = BIO_new_file(argv[4], "rb");
		CMS_ContentInfo* cms = profile ? d2i_CMS_bio(profile, nullptr) : nullptr;
		BIO_free(profile);
		OSSL_PROVIDER_load(nullptr, "legacy");
		BIO* input = BIO_new_file(argv[2], "rb");
		PKCS12* p12 = input ? d2i_PKCS12_bio(input, nullptr) : nullptr;
		BIO_free(input);
		const bool valid = p12 && (PKCS12_verify_mac(p12, nullptr, 0) || PKCS12_verify_mac(p12, argv[3], -1));
		PKCS12_free(p12);
		CMS_ContentInfo_free(cms);
		std::cout << (valid ? "valid" : "rejected") << '\n';
		return 0;
	}
	if (mode == "signing-init") {
		ZSignAsset identity;
		return identity.Init("", argv[2], argv[4], "", argv[3], false, false, false) ? 0 : 1;
	}
	if (mode == "content") {
		std::string content;
		if (ZReadProvisioningContent(argv[4], content) != ZCertificateValidation::valid) return 1;
		std::cout << content;
		return 0;
	}
	const char* names[] = {"valid", "unavailableAlgorithms", "unreadableCertificate", "invalidCertificate",
		"incorrectPassword", "decryptionFailed", "missingPrivateKey", "unreadableProfile", "invalidProfile", "profileMismatch"};
	ZCertificateValidation result = ZCertificateValidation::valid;
	const int count = mode == "repeat" ? 100 : 1;
	for (int index = 0; index < count; ++index)
		result = ZValidateCertificate(argv[2], argv[3], argv[4]);
	std::cout << names[static_cast<int>(result)] << '\n';
	return 0;
}
