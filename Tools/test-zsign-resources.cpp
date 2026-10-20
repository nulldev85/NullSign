#include "common.h"
#include "bundle.h"
#include "macho.h"

// Exercise the production C++ implementation, without Apple credentials or an
// iOS process. The Python driver creates synthetic app bundles and Mach-O files.
int main(int argc, char** argv)
{
    if (argc != 3) return 2;
    ZLog::SetLogLever(ZLog::E_NONE);
    const string command = argv[1];
    if (command == "hash") {
        string sha1, sha256;
        if (!ZSHA::SHABase64File(argv[2], sha1, sha256)) return 1;
        cout << sha1 << "\n" << sha256 << "\n";
        return 0;
    }
    if (command == "sign") {
        ZSignAsset asset;
        if (!asset.Init("", "", "", "", "", true, false, false)) return 2;
        ZBundle bundle;
        return bundle.SignFolder(&asset, argv[2], "", "", "", {}, true, false, false, true) ? 0 : 1;
    }
    if (command == "verify") {
        ZMachO macho;
        return macho.Init(argv[2]) && macho.CheckSignature() ? 0 : 1;
    }
    return 2;
}
