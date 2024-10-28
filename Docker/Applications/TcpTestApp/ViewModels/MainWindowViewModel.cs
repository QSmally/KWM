using Reactive.Bindings;
using System;
using System.Net;
using System.Net.Sockets;
using System.Threading;
using System.Threading.Tasks;
using static System.Console;
using static System.Environment;
using static System.Text.Encoding;
using static System.Threading.Tasks.Task;

namespace TcpTestApp.ViewModels {
    public class MainWindowViewModel : ViewModelBase {
        
        public ReactiveProperty<string> ErrorMessage { get; } = new ReactiveProperty<string>("Error message");
        public ReactiveProperty<string> ServerName { get; } = new ReactiveProperty<string>("extendedwm");
        public ReactiveProperty<string> ServerPort { get; } = new ReactiveProperty<string>("1025");
        
        public ReactiveProperty<string> Layout1 { get; } = new ReactiveProperty<string>("default");
        public ReactiveProperty<string> Layout2 { get; } = new ReactiveProperty<string>("advertisements");
        public ReactiveProperty<string> Layout3 { get; } = new ReactiveProperty<string>("fallback");
        

        private TcpListener? _server;

        public MainWindowViewModel() {
        }

        public async Task SendLayout(string? layout) {
            if(layout == null) return;
            await Run(() => _sendLayout(layout));
        }
        
        public async Task StartServer() {
            await Run(_startServer);
        }

        public async Task StopServer() {
            await Run(_stopServer); 
        }

        private void _sendLayout(string layout) {
            ErrorMessage.Value = $"Sending layout {layout} to {ServerName.Value}";

            if (!int.TryParse(ServerPort.Value, out var port)) {
                ErrorMessage.Value = "port is invalid";
                return;
            }

            try {
                var client = new TcpClient(ServerName.Value, port);
                using var stream = client.GetStream();
                var data = System.Text.Encoding.ASCII.GetBytes($"{{ \"layout_select\": \"{layout}\" }}");
                stream.Write(data, 0, data.Length);
            } catch (Exception ex) {
                ErrorMessage.Value = ex.Message;
            }
        }
            
        private void _startServer() {
            const string localServer = "127.0.0.1";
            
            if (!int.TryParse(ServerPort.Value, out var port)) {
                ErrorMessage.Value = "port is invalid";
                return;
            }
            
            _stopServer();

            try {
                ErrorMessage.Value = $"Starting server {localServer} at port {ServerPort.Value}";
                var localAddr = IPAddress.Parse(localServer);
                _server = new TcpListener(localAddr, port);
                _server.Start();
                _startListener();
            } catch (Exception ex) {
                ErrorMessage.Value = ex.Message;
            }
        }

        private void _stopServer() {
            ErrorMessage.Value = "Stop Server";
            try {
                _server?.Stop();
                ErrorMessage.Value = "Server stopped";
            } catch (Exception ex) {
                ErrorMessage.Value = ex.Message;
            } finally {
                _server = null;
            }
        }

        private void _startListener() {
            try {
                while (true) {
                    ErrorMessage.Value = "Waiting for a connection...";
                    var client = _server?.AcceptTcpClient();
                    if (client == null) {
                        ErrorMessage.Value = "Accept connection failed"; 
                        continue;
                    }
                    
                    ErrorMessage.Value = "Connected!"; 

                    var t = new Thread(_handleDevice);
                    t.Start(client);
                }
            }
            catch (SocketException ex) {
                ErrorMessage.Value = ex.Message;
                _server?.Stop();
            }
        }

        private void _handleDevice(object? obj) {
            if (obj == null)
                return;
            
            using var client = (TcpClient)obj;
            var stream = client.GetStream();

            var bytes = new byte[256];
            try {
                int i;
                while((i = stream.Read(bytes, 0, bytes.Length)) != 0) {
                    var data = ASCII.GetString(bytes, 0, i);
                    ErrorMessage.Value = $"{data}: Received: {CurrentManagedThreadId}";
                }
            } catch (Exception ex) {
                WriteLine($"Exception: {ex}");
            } finally {
                client.Close();
            }
        }
    }
}
