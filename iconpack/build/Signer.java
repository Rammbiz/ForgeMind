import com.android.apksig.ApkSigner;
import com.android.apksig.ApkVerifier;

import java.io.File;
import java.io.FileInputStream;
import java.security.KeyStore;
import java.security.PrivateKey;
import java.security.cert.Certificate;
import java.security.cert.X509Certificate;
import java.util.ArrayList;
import java.util.Collections;
import java.util.List;

/**
 * Thin driver around com.android.apksig: signs an APK with the v1 (JAR) and v2
 * (APK Signature Scheme v2) schemes, or verifies an already signed APK.
 *
 *   java -cp apksig.jar Signer.java sign   <in.apk> <out.apk> <keystore> <storepass> <alias> <keypass> <minSdk>
 *   java -cp apksig.jar Signer.java verify <apk> <minSdk>
 */
public final class Signer {

    public static void main(String[] args) throws Exception {
        if (args.length == 0) {
            usage();
        }
        switch (args[0]) {
            case "sign":
                sign(args);
                break;
            case "verify":
                verify(args);
                break;
            default:
                usage();
        }
    }

    private static void usage() {
        System.err.println("usage: Signer sign <in> <out> <keystore> <storepass> <alias> <keypass> <minSdk>");
        System.err.println("       Signer verify <apk> <minSdk>");
        System.exit(2);
    }

    private static void sign(String[] a) throws Exception {
        if (a.length != 8) {
            usage();
        }
        File in = new File(a[1]);
        File out = new File(a[2]);
        String storePath = a[3];
        char[] storePass = a[4].toCharArray();
        String alias = a[5];
        char[] keyPass = a[6].toCharArray();
        int minSdk = Integer.parseInt(a[7]);
        boolean v1 = !"false".equals(System.getProperty("sign.v1"));
        boolean v2 = !"false".equals(System.getProperty("sign.v2"));

        KeyStore ks = KeyStore.getInstance("PKCS12");
        try (FileInputStream fis = new FileInputStream(storePath)) {
            ks.load(fis, storePass);
        }
        PrivateKey key = (PrivateKey) ks.getKey(alias, keyPass);
        if (key == null) {
            throw new IllegalStateException("no private key for alias " + alias);
        }
        Certificate[] chain = ks.getCertificateChain(alias);
        List<X509Certificate> certs = new ArrayList<>();
        for (Certificate c : chain) {
            certs.add((X509Certificate) c);
        }

        ApkSigner.SignerConfig cfg =
                new ApkSigner.SignerConfig.Builder("CERT", key, certs).build();
        ApkSigner signer = new ApkSigner.Builder(Collections.singletonList(cfg))
                .setInputApk(in)
                .setOutputApk(out)
                .setMinSdkVersion(minSdk)
                .setV1SigningEnabled(v1)
                .setV2SigningEnabled(v2)
                .setCreatedBy("live-takt-iconpack")
                .build();
        signer.sign();
        System.out.println("signed: " + out.getAbsolutePath());
    }

    private static void verify(String[] a) throws Exception {
        if (a.length != 3) {
            usage();
        }
        ApkVerifier.Result r = new ApkVerifier.Builder(new File(a[1]))
                .setMinCheckedPlatformVersion(Integer.parseInt(a[2]))
                .build()
                .verify();
        for (ApkVerifier.IssueWithParams e : r.getErrors()) {
            System.out.println("ERROR: " + e);
        }
        for (ApkVerifier.IssueWithParams w : r.getWarnings()) {
            System.out.println("warning: " + w);
        }
        System.out.println("verified=" + r.isVerified()
                + " v1=" + r.isVerifiedUsingV1Scheme()
                + " v2=" + r.isVerifiedUsingV2Scheme());
        if (!r.isVerified()) {
            System.exit(1);
        }
    }
}
