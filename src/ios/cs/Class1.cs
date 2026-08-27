using System.Runtime.InteropServices;
using SteamKit2;
using SteamKit2.Authentication;

public static class NativeApi
{
    [UnmanagedCallersOnly(EntryPoint = "steamkit2_init")]
    public static int Init()
    {

        return 0;
    }

    [UnmanagedCallersOnly(EntryPoint = "steamkit2")]
    public static int Add(int a, int b)
    {
        return a + b;
    }
}