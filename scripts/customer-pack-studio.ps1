[CmdletBinding()]
param([switch]$SmokeTest)

$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
Import-Module (Join-Path $projectRoot 'src\WorkBuddyDreamSkin.psm1') -Force

Add-Type -AssemblyName PresentationFramework, PresentationCore, WindowsBase
Add-Type -AssemblyName System.Windows.Forms

[xml]$xaml = @'
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="WorkBuddy Dream Skin · 客户定制包" Width="800" Height="620"
        MinWidth="760" MinHeight="580" WindowStartupLocation="CenterScreen"
        Background="#101321" Foreground="#F7F4FF" FontFamily="Microsoft YaHei UI">
  <Window.Resources>
    <Style TargetType="TextBox">
      <Setter Property="Background" Value="#1B2033"/><Setter Property="Foreground" Value="#F7F4FF"/>
      <Setter Property="BorderBrush" Value="#39415F"/><Setter Property="Padding" Value="12,9"/>
    </Style>
    <Style TargetType="ComboBox">
      <Setter Property="Background" Value="#1B2033"/><Setter Property="Foreground" Value="#15192A"/>
      <Setter Property="BorderBrush" Value="#39415F"/><Setter Property="Padding" Value="10,7"/>
    </Style>
    <Style TargetType="Button">
      <Setter Property="Foreground" Value="#FFFFFF"/><Setter Property="Background" Value="#6554D9"/>
      <Setter Property="BorderThickness" Value="0"/><Setter Property="Padding" Value="18,10"/>
      <Setter Property="Cursor" Value="Hand"/><Setter Property="Margin" Value="8,0,0,0"/>
    </Style>
    <Style x:Key="SecondaryButton" TargetType="Button" BasedOn="{StaticResource {x:Type Button}}">
      <Setter Property="Background" Value="#292D43"/>
    </Style>
  </Window.Resources>
  <Grid Margin="30">
    <Grid.RowDefinitions>
      <RowDefinition Height="Auto"/><RowDefinition Height="18"/><RowDefinition Height="*"/><RowDefinition Height="20"/><RowDefinition Height="Auto"/>
    </Grid.RowDefinitions>
    <StackPanel Grid.Row="0">
      <TextBlock Text="制作客户定制安装包" FontSize="28" FontWeight="SemiBold"/>
      <TextBlock Text="选择照片与基础配色，一次生成客户可直接安装的 ZIP。照片只在本机处理。" Foreground="#AEB4CF" Margin="0,7,0,0"/>
    </StackPanel>
    <Grid Grid.Row="2">
      <Grid.ColumnDefinitions><ColumnDefinition Width="*"/><ColumnDefinition Width="22"/><ColumnDefinition Width="270"/></Grid.ColumnDefinitions>
      <StackPanel Grid.Column="0">
        <TextBlock Text="客户名称" Foreground="#C8CEE4" Margin="0,0,0,6"/>
        <TextBox x:Name="ClientNameText"/>
        <TextBlock Text="主题显示名称（可选）" Foreground="#C8CEE4" Margin="0,16,0,6"/>
        <TextBox x:Name="ThemeNameText"/>
        <TextBlock Text="基础配色" Foreground="#C8CEE4" Margin="0,16,0,6"/>
        <ComboBox x:Name="BaseThemeCombo" DisplayMemberPath="Name"/>
        <TextBlock Text="客户照片" Foreground="#C8CEE4" Margin="0,16,0,6"/>
        <Grid><Grid.ColumnDefinitions><ColumnDefinition Width="*"/><ColumnDefinition Width="Auto"/></Grid.ColumnDefinitions>
          <TextBox x:Name="ImagePathText" IsReadOnly="True"/>
          <Button x:Name="BrowseImageButton" Grid.Column="1" Content="选择照片" Style="{StaticResource SecondaryButton}"/>
        </Grid>
        <TextBlock Text="输出位置" Foreground="#C8CEE4" Margin="0,16,0,6"/>
        <Grid><Grid.ColumnDefinitions><ColumnDefinition Width="*"/><ColumnDefinition Width="Auto"/></Grid.ColumnDefinitions>
          <TextBox x:Name="OutputPathText" IsReadOnly="True"/>
          <Button x:Name="BrowseOutputButton" Grid.Column="1" Content="选择文件夹" Style="{StaticResource SecondaryButton}"/>
        </Grid>
      </StackPanel>
      <Border Grid.Column="2" Background="#191D2E" BorderBrush="#39415F" BorderThickness="1" CornerRadius="18" ClipToBounds="True">
        <Grid>
          <Image x:Name="ImagePreview" Stretch="UniformToFill"/>
          <Border VerticalAlignment="Bottom" Background="#CC111522" Padding="18">
            <StackPanel>
              <TextBlock Text="客户主题预览" FontSize="18" FontWeight="SemiBold"/>
              <TextBlock Text="建议使用主体清晰、分辨率较高的横图或方图。" Foreground="#BFC5DB" TextWrapping="Wrap" Margin="0,5,0,0"/>
            </StackPanel>
          </Border>
        </Grid>
      </Border>
    </Grid>
    <Grid Grid.Row="4">
      <Grid.ColumnDefinitions><ColumnDefinition Width="*"/><ColumnDefinition Width="Auto"/></Grid.ColumnDefinitions>
      <TextBlock x:Name="StatusText" VerticalAlignment="Center" Foreground="#AEB4CF" Text="填写信息后生成客户安装包。" TextWrapping="Wrap"/>
      <Button x:Name="BuildButton" Grid.Column="1" Content="生成客户安装包" Padding="24,12"/>
    </Grid>
  </Grid>
</Window>
'@

$reader = New-Object System.Xml.XmlNodeReader $xaml
$window = [Windows.Markup.XamlReader]::Load($reader)
$clientNameText = $window.FindName('ClientNameText')
$themeNameText = $window.FindName('ThemeNameText')
$baseThemeCombo = $window.FindName('BaseThemeCombo')
$imagePathText = $window.FindName('ImagePathText')
$outputPathText = $window.FindName('OutputPathText')
$imagePreview = $window.FindName('ImagePreview')
$browseImageButton = $window.FindName('BrowseImageButton')
$browseOutputButton = $window.FindName('BrowseOutputButton')
$statusText = $window.FindName('StatusText')
$buildButton = $window.FindName('BuildButton')

$themes = @(Get-WbdsThemes -ProjectRoot $projectRoot | Where-Object { $_.HasBackground -and $_.Kind -ne 'customer' })
$baseThemeCombo.ItemsSource = $themes
$preferred = $themes | Where-Object Id -eq 'dream-glass' | Select-Object -First 1
if ($preferred) { $baseThemeCombo.SelectedItem = $preferred } elseif ($themes.Count) { $baseThemeCombo.SelectedIndex = 0 }
$outputPathText.Text = [Environment]::GetFolderPath('Desktop')

function Set-CustomerPackStatus {
    param([string]$Message, [bool]$IsError = $false)
    $statusText.Text = $Message
    $statusText.Foreground = if ($IsError) { '#FFFF8D8D' } else { '#FFAEB4CF' }
}

$browseImageButton.Add_Click({
    $dialog = New-Object System.Windows.Forms.OpenFileDialog
    $dialog.Title = '选择客户主题照片'
    $dialog.Filter = '图片文件|*.jpg;*.jpeg;*.png;*.webp;*.gif'
    if ($dialog.ShowDialog() -ne [System.Windows.Forms.DialogResult]::OK) { return }
    $imagePathText.Text = $dialog.FileName
    $bitmap = New-Object Windows.Media.Imaging.BitmapImage
    $bitmap.BeginInit(); $bitmap.CacheOption = 'OnLoad'; $bitmap.UriSource = [Uri]$dialog.FileName; $bitmap.EndInit(); $bitmap.Freeze()
    $imagePreview.Source = $bitmap
    Set-CustomerPackStatus '照片已选择，只会在本机写入客户安装包。'
})

$browseOutputButton.Add_Click({
    $dialog = New-Object System.Windows.Forms.FolderBrowserDialog
    $dialog.Description = '选择客户安装包的保存位置'
    if ($dialog.ShowDialog() -ne [System.Windows.Forms.DialogResult]::OK) { return }
    $outputPathText.Text = $dialog.SelectedPath
})

$buildButton.Add_Click({
    try {
        if (-not $baseThemeCombo.SelectedItem) { throw '请选择基础配色。' }
        Set-CustomerPackStatus '正在生成客户安装包……'
        $buildButton.IsEnabled = $false
        $arguments = @{
            ClientName = $clientNameText.Text
            BackgroundPath = $imagePathText.Text
            BaseThemePath = $baseThemeCombo.SelectedItem.Path
            OutputDirectory = $outputPathText.Text
        }
        if ($themeNameText.Text.Trim()) { $arguments.ThemeName = $themeNameText.Text.Trim() }
        $result = & (Join-Path $PSScriptRoot 'build-customer-pack.ps1') @arguments
        Set-CustomerPackStatus "已生成：$($result.Archive)"
        [System.Windows.MessageBox]::Show("客户安装包已生成：`n`n$($result.Archive)`n`n同时生成了 SHA256 校验文件。", '生成完成', 'OK', 'Information') | Out-Null
        Start-Process -FilePath 'explorer.exe' -ArgumentList @('/select,', $result.Archive) | Out-Null
    } catch {
        Set-CustomerPackStatus $_.Exception.Message $true
        [System.Windows.MessageBox]::Show($_.Exception.Message, '生成失败', 'OK', 'Error') | Out-Null
    } finally {
        $buildButton.IsEnabled = $true
    }
})

if ($SmokeTest) {
    if (-not $baseThemeCombo.SelectedItem) { throw 'Customer Pack Studio did not load a base theme.' }
    if (-not $outputPathText.Text) { throw 'Customer Pack Studio did not set an output folder.' }
    Write-Host "PASS: Customer Pack Studio loaded $($themes.Count) base theme(s)." -ForegroundColor Green
    exit 0
}

$null = $window.ShowDialog()
