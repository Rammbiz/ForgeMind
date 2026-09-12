package android.content;
public class Intent {
    public Intent() {}
    public Intent(String action) {}
    public Intent putExtra(String name, String value) { return this; }
    public Intent setPackage(String packageName) { return this; }
    public Intent addFlags(int flags) { return this; }
}
