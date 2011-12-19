using System;
using System.IO;
using System.Net;
using System.Reflection;
using System.Runtime.InteropServices;

using MonoMac.AppKit;
using MonoMac.Foundation;

using Mono.Cecil;
using Mono.Cecil.Cil;

namespace MacTerrariaWrapper
{
	static class Program
	{
		/// <summary>
		/// The main entry point for the application.
		/// </summary>
		static void Main (string[] args)
		{
			NSApplication.Init ();
			
			using (var p = new NSAutoreleasePool ()) {
				NSApplication.SharedApplication.Delegate = new AppDelegate();
				NSApplication.Main(args);
			}


		}
	}
	
	class AppDelegate : NSApplicationDelegate
	{
		
		[DllImport ("rlimit")]
		private static extern int getMaxfiles();
		
		private void patchTerraria(string filename, string outfilename) {
			
			AssemblyDefinition assembly = AssemblyDefinition.ReadAssembly(filename);
			
			foreach(AssemblyNameReference asmref in assembly.MainModule.AssemblyReferences) {
				if (asmref.Name.StartsWith("Microsoft.Xna.Framework")) {
					asmref.Name = "MonoGame.Framework.MacOS";
					asmref.PublicKeyToken = null;
					asmref.Version = new Version("1.0.0.0");
				}
			}
			
			TypeDefinition t = assembly.MainModule.GetType("Terraria.NetMessage");
			foreach (MethodDefinition md in t.Methods) {
				if (md.HasBody && md.Body.Method.Name == "SendData") {
					ILProcessor processor = md.Body.GetILProcessor();
					while (true) {
						bool fixedAnIns = false;
						foreach (Instruction ins in md.Body.Instructions) {
							if (ins.OpCode == OpCodes.Callvirt) {
								MethodReference op = (MethodReference)ins.Operand;
								if (op.Name == "BeginWrite") {
									
									Instruction repins = ins.Previous;
									while (repins.OpCode != OpCodes.Ldloc_1) {
										repins = repins.Previous;
										processor.Remove(repins.Next);
									}
									
									if (ins.Next.OpCode == OpCodes.Pop) {
										processor.Remove(ins.Next);
									}
									
									MethodReference newMethod = md.Module.Import(typeof (System.IO.Stream).GetMethod("Write"));
									processor.Replace(ins, processor.Create(OpCodes.Callvirt, newMethod));
									
									Console.WriteLine ("monkeypatched terraria bug! :D");
									
									fixedAnIns = true;
									break;
								}
							}
						}
						if (!fixedAnIns) break;
					}
					
				}
				break;
			}
			assembly.Write(outfilename);
		}
		
		private void runCommand(string szCmd, string szArgs)
		{
			System.Diagnostics.Process myproc = new System.Diagnostics.Process();
			myproc.EnableRaisingEvents = false;
			myproc.StartInfo.FileName = szCmd;
			myproc.StartInfo.Arguments = szArgs;
			myproc.Start();
			myproc.WaitForExit();
		}
		
		public override void FinishedLaunching (MonoMac.Foundation.NSObject notification)
		{
			Directory.SetCurrentDirectory(NSBundle.MainBundle.ResourcePath);
			
			if (getMaxfiles() < 512) {
				runCommand("launchctl", "limit maxfiles 512 4096");
				
				string execPath = NSBundle.MainBundle.BundlePath;
				int processId = NSProcessInfo.ProcessInfo.ProcessIdentifier;
				NSTask.LaunchFromPath("relaunch", new string[]{execPath, processId.ToString()});
				
				Environment.Exit(0);
			}
			
			WebClient updateClient = new WebClient();
			updateClient.DownloadStringCompleted += UpdateCheckCompleted;
			updateClient.DownloadStringAsync(new Uri("http://dl.dropbox.com/u/76985/MacTerraria_update.txt"));
			
			patchTerraria(Path.Combine(NSBundle.MainBundle.ResourcePath, "exes", "Terraria.exe"),
			              Path.Combine(NSBundle.MainBundle.ResourcePath, "Terraria.exe"));
			
			string savePath = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.Personal), "My Games", "Terraria");
			Directory.CreateDirectory(savePath);
			
			
			
			Assembly assembly = Assembly.LoadFrom(Path.Combine(NSBundle.MainBundle.ResourcePath, "Terraria.exe"));
			Type mainType = assembly.GetType("Terraria.Main");
			object game = Activator.CreateInstance(mainType);
			
			mainType.InvokeMember("Run", BindingFlags.Default | BindingFlags.InvokeMethod, null, game, null);
		}
		
		private static void UpdateCheckCompleted(object sender, DownloadStringCompletedEventArgs e)
		{
			int curVersion = int.Parse(NSBundle.MainBundle.InfoDictionary.ObjectForKey(new NSString("CFBundleVersion")).ToString());
			
			int updateVersion;
			if (int.TryParse(e.Result, out updateVersion)) {
				if (updateVersion > curVersion) {
					using (NSAlert alert = NSAlert.WithMessage("Update", "Visit Download Page", "Cancel", null,
					                      "An update to the wrapper is available!") ) {
						int result = alert.RunModal();
						if (result == 1) {
							NSWorkspace.SharedWorkspace.OpenUrl(NSUrl.FromString(
						                                 "http://www.terrariaonline.com/threads/terraria-mac-wrapper.15236/"));
						}
					}
				}
			}
		}
		
		
		public override bool ApplicationShouldTerminateAfterLastWindowClosed (NSApplication sender)
		{
			return true;
		}
	}		
}

