[CmdletBinding()]
param([switch]$SmokeTest)

$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
Import-Module (Join-Path $projectRoot 'src\WorkBuddyDreamSkin.psm1') -Force

function Initialize-WbdsThemeShells {
    $examplesRoot = Join-Path $projectRoot 'theme-examples'
    $localRoot = Join-Path $projectRoot 'themes-local'
    New-Item -ItemType Directory -Path $localRoot -Force | Out-Null
    foreach ($example in (Get-ChildItem -LiteralPath $examplesRoot -Directory -ErrorAction SilentlyContinue)) {
        $source = Join-Path $example.FullName 'theme.example.json'
        $targetDirectory = Join-Path $localRoot $example.Name
        $target = Join-Path $targetDirectory 'theme.json'
        if (Test-Path -LiteralPath $source -PathType Leaf) {
            New-Item -ItemType Directory -Path $targetDirectory -Force | Out-Null
            $config = Get-Content -LiteralPath $source -Raw -Encoding UTF8 | ConvertFrom-Json
            $existingImage = ''
            if (Test-Path -LiteralPath $target -PathType Leaf) {
                try {
                    $existing = Get-Content -LiteralPath $target -Raw -Encoding UTF8 | ConvertFrom-Json
                    if ($existing.backgroundImage) {
                        $candidate = Join-Path $targetDirectory ([string]$existing.backgroundImage)
                        if (Test-Path -LiteralPath $candidate -PathType Leaf) { $existingImage = [string]$existing.backgroundImage }
                    }
                } catch {}
            }
            if (-not $existingImage) {
                $packagedImage = Get-ChildItem -LiteralPath $example.FullName -File -ErrorAction SilentlyContinue |
                    Where-Object { $_.Extension.ToLowerInvariant() -in @('.jpg', '.jpeg', '.png', '.webp', '.gif') } |
                    Select-Object -First 1
                if ($packagedImage) {
                    Copy-Item -LiteralPath $packagedImage.FullName -Destination (Join-Path $targetDirectory $packagedImage.Name) -Force
                    $existingImage = $packagedImage.Name
                }
            }
            $config.backgroundImage = $existingImage
            $config | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $target -Encoding UTF8
        }
    }
}

function Get-WbdsPreviewColors {
    param([string]$ThemePath)
    $config = Get-Content -LiteralPath $ThemePath -Raw -Encoding UTF8 | ConvertFrom-Json
    $matches = [regex]::Matches([string]$config.backgroundFallback, '#[0-9a-fA-F]{6}')
    $first = if ($matches.Count) { $matches[0].Value } else { '#171a2d' }
    $last = if ($matches.Count -gt 1) { $matches[$matches.Count - 1].Value } else { '#3a315c' }
    return @($first, $last)
}

function Get-WbdsPreviewImage {
    param([string]$ThemePath)
    $config = Get-Content -LiteralPath $ThemePath -Raw -Encoding UTF8 | ConvertFrom-Json
    if (-not $config.backgroundImage) { return $null }
    $candidate = Join-Path (Split-Path -Parent $ThemePath) ([string]$config.backgroundImage)
    if (Test-Path -LiteralPath $candidate -PathType Leaf) { return $candidate }
    return $null
}

Initialize-WbdsThemeShells
$initialThemes = @(Get-WbdsThemes -ProjectRoot $projectRoot)
if ($SmokeTest) {
    if ($initialThemes.Count -lt 6) { throw "Theme Studio expected at least 6 themes, found $($initialThemes.Count)." }
}

Add-Type -AssemblyName PresentationFramework, PresentationCore, WindowsBase
Add-Type -AssemblyName System.Windows.Forms

[xml]$xaml = @'
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="WorkBuddy Dream Skin · 主题中心" Width="960" Height="650"
        MinWidth="820" MinHeight="560" WindowStartupLocation="CenterScreen"
        Background="#101321" Foreground="#F7F4FF" FontFamily="Microsoft YaHei UI">
  <Window.Resources>
    <Style TargetType="Button">
      <Setter Property="Foreground" Value="#FFFFFF"/><Setter Property="Background" Value="#6554D9"/>
      <Setter Property="BorderThickness" Value="0"/><Setter Property="Padding" Value="18,10"/>
      <Setter Property="Margin" Value="0,0,10,0"/><Setter Property="Cursor" Value="Hand"/>
    </Style>
    <Style x:Key="SecondaryButton" TargetType="Button" BasedOn="{StaticResource {x:Type Button}}">
      <Setter Property="Background" Value="#292D43"/>
    </Style>
  </Window.Resources>
  <Grid Margin="28">
    <Grid.RowDefinitions><RowDefinition Height="Auto"/><RowDefinition Height="*"/><RowDefinition Height="Auto"/></Grid.RowDefinitions>
    <StackPanel Grid.Row="0" Margin="0,0,0,20">
      <TextBlock Text="WorkBuddy Dream Skin" FontSize="28" FontWeight="SemiBold"/>
      <TextBlock Text="每个内置主题包含图片与整套界面配色；导入图片只替换当前主题的壁纸。" Foreground="#AEB4CF" Margin="0,7,0,0"/>
    </StackPanel>
    <Grid Grid.Row="1">
      <Grid.ColumnDefinitions><ColumnDefinition Width="360"/><ColumnDefinition Width="24"/><ColumnDefinition Width="*"/></Grid.ColumnDefinitions>
      <Border Grid.Column="0" Background="#191D2E" CornerRadius="14" Padding="10">
        <ListBox x:Name="ThemeList" Background="Transparent" BorderThickness="0" Foreground="#FFFFFF">
          <ListBox.ItemTemplate>
            <DataTemplate>
              <StackPanel Margin="8,9">
                <TextBlock Text="{Binding Name}" FontSize="16" FontWeight="SemiBold"/>
                <TextBlock Text="{Binding Description}" Foreground="#9FA7C4" TextWrapping="Wrap" Margin="0,4,0,0"/>
              </StackPanel>
            </DataTemplate>
          </ListBox.ItemTemplate>
        </ListBox>
      </Border>
      <Border x:Name="Preview" Grid.Column="2" CornerRadius="18" Background="#242942" ClipToBounds="True">
        <Grid>
          <Border Background="#66101422"/>
          <StackPanel VerticalAlignment="Bottom" Margin="28">
            <Border Background="#CC161A2A" CornerRadius="12" Padding="18">
              <StackPanel>
                <TextBlock x:Name="PreviewName" FontSize="24" FontWeight="SemiBold"/>
                <TextBlock x:Name="PreviewDescription" Foreground="#C4C9DC" TextWrapping="Wrap" Margin="0,6,0,0"/>
              </StackPanel>
            </Border>
          </StackPanel>
        </Grid>
      </Border>
    </Grid>
    <Grid Grid.Row="2" Margin="0,22,0,0">
      <Grid.ColumnDefinitions><ColumnDefinition Width="*"/><ColumnDefinition Width="Auto"/></Grid.ColumnDefinitions>
      <TextBlock x:Name="StatusText" VerticalAlignment="Center" Foreground="#AEB4CF" Text="请选择一个主题。" TextWrapping="Wrap"/>
      <StackPanel Grid.Column="1" Orientation="Horizontal">
        <Button x:Name="ImportButton" Content="只替换主题图片" Style="{StaticResource SecondaryButton}"/>
        <Button x:Name="RestoreButton" Content="恢复官方外观" Style="{StaticResource SecondaryButton}"/>
        <Button x:Name="ApplyButton" Content="应用主题"/>
      </StackPanel>
    </Grid>
  </Grid>
</Window>
'@

$reader = New-Object System.Xml.XmlNodeReader $xaml
$window = [Windows.Markup.XamlReader]::Load($reader)
$themeList = $window.FindName('ThemeList')
$preview = $window.FindName('Preview')
$previewName = $window.FindName('PreviewName')
$previewDescription = $window.FindName('PreviewDescription')
$statusText = $window.FindName('StatusText')
$importButton = $window.FindName('ImportButton')
$restoreButton = $window.FindName('RestoreButton')
$applyButton = $window.FindName('ApplyButton')

function Update-WbdsThemeList {
    param([string]$SelectId)
    $items = @(Get-WbdsThemes -ProjectRoot $projectRoot)
    $themeList.ItemsSource = $items
    if ($SelectId) { $themeList.SelectedItem = $items | Where-Object Id -eq $SelectId | Select-Object -First 1 }
    if (-not $themeList.SelectedItem -and $items.Count) { $themeList.SelectedIndex = 0 }
}

function Set-WbdsStatus {
    param([string]$Message, [bool]$IsError = $false)
    $statusText.Text = $Message
    $statusText.Foreground = if ($IsError) { '#FFFF8D8D' } else { '#FFAEB4CF' }
}

$themeList.Add_SelectionChanged({
    $selected = $themeList.SelectedItem
    if (-not $selected) { return }
    $previewName.Text = $selected.Name
    $previewDescription.Text = $selected.Description
    $imagePath = Get-WbdsPreviewImage -ThemePath $selected.Path
    if ($imagePath) {
        $bitmap = New-Object Windows.Media.Imaging.BitmapImage
        $bitmap.BeginInit(); $bitmap.CacheOption = 'OnLoad'; $bitmap.UriSource = [Uri]$imagePath; $bitmap.EndInit(); $bitmap.Freeze()
        $brush = New-Object Windows.Media.ImageBrush $bitmap
        $brush.Stretch = 'UniformToFill'
        $preview.Background = $brush
    } else {
        $colors = Get-WbdsPreviewColors -ThemePath $selected.Path
        $brush = New-Object Windows.Media.LinearGradientBrush
        $brush.StartPoint = New-Object Windows.Point(0, 0)
        $brush.EndPoint = New-Object Windows.Point(1, 1)
        $brush.GradientStops.Add((New-Object Windows.Media.GradientStop ([Windows.Media.ColorConverter]::ConvertFromString($colors[0])), 0))
        $brush.GradientStops.Add((New-Object Windows.Media.GradientStop ([Windows.Media.ColorConverter]::ConvertFromString($colors[1])), 1))
        $preview.Background = $brush
    }
    Set-WbdsStatus "已选择：$($selected.Name)"
})

$importButton.Add_Click({
    try {
        $selected = $themeList.SelectedItem
        if (-not $selected) { throw '请先选择一个主题作为样式基础。' }
        $dialog = New-Object System.Windows.Forms.OpenFileDialog
        $dialog.Title = '选择背景图片'
        $dialog.Filter = '图片文件|*.jpg;*.jpeg;*.png;*.webp;*.gif'
        if ($dialog.ShowDialog() -ne [System.Windows.Forms.DialogResult]::OK) { return }
        $file = Get-Item -LiteralPath $dialog.FileName
        if ($file.Length -gt 12MB) { throw '图片不能超过 12 MB。' }

        $custom = New-WbdsCustomTheme -ProjectRoot $projectRoot -BaseThemePath $selected.Path -BackgroundPath $file.FullName
        Update-WbdsThemeList -SelectId $custom.Id
        Set-WbdsStatus '图片已导入本机。点击“应用主题”即可查看效果。'
    } catch {
        Set-WbdsStatus $_.Exception.Message $true
        [System.Windows.MessageBox]::Show($_.Exception.Message, '导入失败', 'OK', 'Error') | Out-Null
    }
})

$applyButton.Add_Click({
    try {
        $selected = $themeList.SelectedItem
        if (-not $selected) { throw '请先选择一个主题。' }
        Set-WbdsStatus '正在启动 WorkBuddy 并应用主题……'
        $script = Join-Path $PSScriptRoot 'start-dream-skin.ps1'
        $output = & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $script -ThemePath $selected.Path 2>&1 | Out-String
        if ($LASTEXITCODE -ne 0) { throw ($output.Trim()) }
        Set-WbdsStatus "已应用：$($selected.Name)"
    } catch {
        $message = $_.Exception.Message
        if ($message -like '*already running*') { $message = 'WorkBuddy 正在普通模式运行。请先从托盘完全退出 WorkBuddy，再点击“应用主题”。' }
        Set-WbdsStatus $message $true
        [System.Windows.MessageBox]::Show($message, '应用失败', 'OK', 'Warning') | Out-Null
    }
})

$restoreButton.Add_Click({
    try {
        $script = Join-Path $PSScriptRoot 'restore-dream-skin.ps1'
        $output = & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $script 2>&1 | Out-String
        if ($LASTEXITCODE -ne 0) { throw ($output.Trim()) }
        Set-WbdsStatus '已恢复 WorkBuddy 官方外观。'
    } catch {
        Set-WbdsStatus $_.Exception.Message $true
        [System.Windows.MessageBox]::Show($_.Exception.Message, '恢复失败', 'OK', 'Error') | Out-Null
    }
})

$preferredThemeId = $null
$customerDefaultPath = Join-Path $projectRoot 'customer-default-theme.txt'
if (Test-Path -LiteralPath $customerDefaultPath -PathType Leaf) {
    $preferredThemeId = (Get-Content -LiteralPath $customerDefaultPath -Raw -Encoding ASCII).Trim()
}
Update-WbdsThemeList -SelectId $preferredThemeId
if ($SmokeTest) {
    if (-not $themeList.SelectedItem) { throw 'Theme Studio did not select an initial theme.' }
    if ($preferredThemeId -and $themeList.SelectedItem.Id -ne $preferredThemeId) { throw 'Theme Studio did not preselect the customer theme.' }
    Write-Host "PASS: Theme Studio loaded $($initialThemes.Count) themes and rendered its window." -ForegroundColor Green
    exit 0
}
$null = $window.ShowDialog()
