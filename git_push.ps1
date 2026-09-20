param(
    [Parameter(Mandatory=$false)]
    [string]$RepoUrl
)

if (-not $RepoUrl) {
    Write-Host ""
    Write-Host "===============================================================" -ForegroundColor Cyan
    Write-Host "КАК ОТПРАВИТЬ РЕПОЗИТОРИЙ В GITHUB ДЛЯ АВТОСБОРКИ .IPA:" -ForegroundColor Yellow
    Write-Host "===============================================================" -ForegroundColor Cyan
    Write-Host "1. Создайте пустой репозиторий на https://github.com/new"
    Write-Host "2. Скопируйте ссылку на репозиторий (например: https://github.com/user/kalkan.git)"
    Write-Host "3. Запустите:" -ForegroundColor Green
    Write-Host "   .\git_push.ps1 https://github.com/ВАШ_АККАУНТ/ВАШ_РЕПОЗИТОРИЙ.git" -ForegroundColor Green
    Write-Host ""
    Write-Host "После push GitHub Actions автоматически соберет KALKAN_SPORT.ipa на macOS!" -ForegroundColor Cyan
    Write-Host "===============================================================" -ForegroundColor Cyan
    exit 0
}

Write-Host "Привязка удаленного репозитория: $RepoUrl" -ForegroundColor Cyan
git remote remove origin 2>$null
git remote add origin $RepoUrl
git branch -M main

Write-Host "Отправка коммитов в ветку main..." -ForegroundColor Cyan
git push -u origin main

if ($LASTEXITCODE -eq 0) {
    Write-Host ""
    Write-Host "УСПЕХ! Проект отправлен в GitHub." -ForegroundColor Green
    Write-Host "Перейдите во вкладку 'Actions' в вашем репозитории на GitHub:" -ForegroundColor Yellow
    Write-Host "Там уже запущена сборка 'Build iOS IPA' на виртуальной macOS машине." -ForegroundColor Yellow
    Write-Host "По завершении вы сможете скачать готовый файл 'KALKAN_SPORT_iOS_IPA' (.ipa)." -ForegroundColor Green
} else {
    Write-Host "Ошибка при push. Проверьте права доступа или авторизацию GitHub." -ForegroundColor Red
}
