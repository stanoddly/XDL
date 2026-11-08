using System;
using System.Runtime.InteropServices;

namespace XDL.LinkTest;

// Each call binds one archive's P/Invoke module; the GPU driver list shows that XDL3.a contains the WebGPU backend.
internal static partial class Program
{
    private static int Main()
    {
        Console.WriteLine($"XDL {SDL_GetVersion()}, SDL_image {IMG_Version()}, SDL_mixer {MIX_Version()}, SDL_ttf {TTF_Version()}");
        int driverCount = SDL_GetNumGPUDrivers();
        string? firstDriver = driverCount > 0 ? Marshal.PtrToStringUTF8(SDL_GetGPUDriver(0)) : null;
        Console.WriteLine($"GPU drivers: {driverCount}, first: {firstDriver}");
        string? revision = Marshal.PtrToStringUTF8(SDL_GetRevision());
        Console.WriteLine($"Revision: {revision}");
        bool ttf = TTF_Init();
        bool mixer = MIX_Init();
        Console.WriteLine($"TTF_Init: {ttf}, MIX_Init: {mixer}");

        bool passed = driverCount == 1 && firstDriver == "webgpu" && revision != null && revision.Contains("XDL-") && ttf && mixer;
        Console.WriteLine(passed ? "XDL link test PASSED" : "XDL link test FAILED");
        return passed ? 0 : 1;
    }

    [LibraryImport("XDL3")]
    private static partial int SDL_GetVersion();

    [LibraryImport("XDL3")]
    private static partial IntPtr SDL_GetRevision();

    [LibraryImport("XDL3")]
    private static partial int SDL_GetNumGPUDrivers();

    [LibraryImport("XDL3")]
    private static partial IntPtr SDL_GetGPUDriver(int index);

    [LibraryImport("XDL3_image")]
    private static partial int IMG_Version();

    [LibraryImport("XDL3_mixer")]
    private static partial int MIX_Version();

    [LibraryImport("XDL3_mixer")]
    [return: MarshalAs(UnmanagedType.U1)]
    private static partial bool MIX_Init();

    [LibraryImport("XDL3_ttf")]
    private static partial int TTF_Version();

    [LibraryImport("XDL3_ttf")]
    [return: MarshalAs(UnmanagedType.U1)]
    private static partial bool TTF_Init();
}
