using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;
using static Avalonia.Win32.Interop.UnmanagedMethods;

namespace Avalonia.Win32
{
    public static class LastResortHandleDestroyer
    {
        private static List<IntPtr> s_handles = new List<IntPtr>();

        public static void DestroyAll()
        {
            lock (s_handles)
            {
                foreach (var handle in s_handles)
                {
                    if (handle != IntPtr.Zero)
                    {
                        DestroyWindow(handle);
                    }
                }

                s_handles.Clear();
            }
        }


        public static void Register(IntPtr handle)
        {
            lock (s_handles)
            {
                s_handles.Add(handle);
            }
        }

        public static void Unregister(IntPtr handle)
        {
            lock (s_handles)
            {
                s_handles.Remove(handle);
            }
        }

    }
}
