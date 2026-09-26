# Как загрузить NextU на GitHub

Это репозиторий нативного iPhone-приложения. GitHub хранит исходники и проверяет сборку. GitHub Pages не запускает SwiftUI как сайт.

## Через GitHub Desktop — удобнее всего

1. Распакуйте `NextU-GitHub-v3.zip`. В папке должны лежать `NextU.xcodeproj`, Swift-файлы, `Assets.xcassets`, `.github`, README и остальные файлы.
2. Установите GitHub Desktop с https://desktop.github.com/ и войдите в свой GitHub.
3. File → Add Local Repository → Choose: выберите распакованную папку `NextU-GitHub`. Если программа пишет, что это не Git-репозиторий, нажмите предложенное `create a repository here`. Проверьте Local path, чтобы это была именно папка с кодом, а не пустая вложенная папка.
4. Если файлы ещё не закоммичены: Summary → `NextU 0.3`, затем Commit to main.
5. Нажмите Publish repository. Название — например `NextU`. Опция Keep this code private сохраняет репозиторий закрытым. Нажмите Publish repository.
6. Откройте View on GitHub → Actions → iOS build and logic checks. Дождитесь результата. Зелёный статус означает, что проверки и сборка прошли в среде GitHub; он не заменяет проверку интерфейса на iPhone.

## Через сайт GitHub

1. Создайте новый репозиторий через https://github.com/new .
2. На пустой странице выберите `uploading an existing file` (в существующем репозитории: Add file → Upload files).
3. Перетащите **содержимое распакованной папки**, не ZIP. Сохраните вложенные папки `NextU.xcodeproj`, `Assets.xcassets`, `scripts`, `Tests` и `.github`. На Mac скрытые файлы показывает ⌘⇧. .
4. Введите `NextU 0.3` и нажмите Commit changes.
5. Проверьте, что на главной странице лежит `NextU.xcodeproj`, а `.github/workflows/ios.yml` присутствует: он включает автоматическую сборку.

Если браузер не переносит Xcode-пакет как папку или скрытые файлы, используйте GitHub Desktop.

## Через терминал

Создайте на GitHub пустой репозиторий без README. В Terminal откройте распакованную папку и выполните (замените YOUR_USERNAME):

```sh
git init -b main
git add .
git commit -m "NextU 0.3"
git remote add origin https://github.com/YOUR_USERNAME/NextU.git
git push -u origin main
```

## После загрузки

На Mac скачайте Code → Download ZIP, распакуйте и откройте `NextU.xcodeproj`. Для установки на свой iPhone укажите Team в Xcode. Подпись Apple ID не хранится в архиве.

Не выкладывайте заново только ZIP вместо исходников — так GitHub Actions не найдёт проект. В этой поставке нет API-ключей, сертификатов или профилей подписи.

Официальная инструкция: https://docs.github.com/en/repositories/working-with-files/managing-files/adding-a-file-to-a-repository
