using Avalonia.Controls;
using Avalonia.Interactivity;
using Avalonia.ReactiveUI;
using TcpTestApp.ViewModels;

namespace TcpTestApp.Views;

public partial class MainWindow : ReactiveWindow<MainWindowViewModel> {
    public MainWindow() {
        InitializeComponent();
    }
    private void Button_Layout1(object? sender, RoutedEventArgs e) {
        ViewModel?.SendLayout(ViewModel.Layout1.Value);
    }
    
    private void Button_Layout2(object? sender, RoutedEventArgs e) {
        ViewModel?.SendLayout(ViewModel.Layout2.Value);
    }
    
    private void Button_Layout3(object? sender, RoutedEventArgs e) {
        ViewModel?.SendLayout(ViewModel.Layout3.Value);
    }
    
    private void Button_Start(object? sender, RoutedEventArgs e) {
        ViewModel?.StartServer();
    }
    private void Button_Stop(object? sender, RoutedEventArgs e) {
        ViewModel?.StopServer();
    }
}
