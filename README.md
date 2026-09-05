## Usage

```text
1. Configure script-settings.json if needed.

2. Run:
   powershell -ExecutionPolicy Bypass -File .\codex-handoff-bundle.ps1 -ProjectPath "C:\_AYKAN_OSBASE\Projects\mywebproject\website"

3. The tool automatically creates:
   - website.zip
   - AI_HANDOFF_BUNDLE_<timestamp>.zip
   - AI_CONTINUATION_PROMPT.txt       (Turkish)
     or
   - AI_CONTINUATION_PROMPT_EN.txt    (English)

4. Give the generated project ZIP, handoff ZIP, and continuation prompt to the next AI.
ex. prompt_en: The instructions are in the AI_CONTINUATION_PROMPT*.txt file inside the AI_HANDOFF_BUNDLE_*.zip; read it and follow the instructions.
    prompt_tr: talimatlar AI_HANDOFF_BUNDLE_*.zip içerisindeki AI_CONTINUATION_PROMPT*.txt içerisinde yazıyor, oku ve talimatlara göre ilerle.
```

### Settings

`script-settings.json` is stored next to `codex-handoff-bundle.ps1`.

If it does not exist, it is created automatically.

Example:

```json
{
  "promptLanguage": "tr",
  "exclude": {
    "folders": [
      ".git",
      "node_modules",
      "target",
      "dist",
      "build"
    ],
    "files": [
      "*.log",
      "*.tmp"
    ]
  }
}
```

Prompt language:

```json
"promptLanguage": "tr"
```

uses:

```text
codex-handoff-prompt-generator-tr.ps1
```

and generates:

```text
AI_CONTINUATION_PROMPT.txt
```

For English:

```json
"promptLanguage": "en"
```

uses:

```text
codex-handoff-prompt-generator-en.ps1
```

and generates:

```text
AI_CONTINUATION_PROMPT_EN.txt
```

No script renaming or manual language switching is required.

Folder and file exclusions are applied globally during relevant project/archive/workspace scans. Folder-name exclusions also apply while scanning parent and grandparent locations, so matching directories are not traversed.

The project ZIP is created automatically before continuation-prompt generation. The handoff bundle is also ZIPped before prompt generation so the prompt can reference the real archive names. After the prompt and archive-omission report are generated, the handoff ZIP is refreshed so the final archive includes them.

---

## English

A PowerShell recovery and handoff toolkit for interrupted Codex/AI coding sessions.

It reconstructs unfinished AI development work by collecting project state, related Codex sessions, user prompts, `apply_patch` history, external workspaces, source-tree differences, and other recovery evidence into a portable handoff bundle that can be given directly to another coding agent.

Unlike a simple conversation export, the tool does not assume that the main project directory contains the latest work. Codex may leave newer changes in staging, worktree, scratch, temporary, backup, shadow, or other external directories. The toolkit automatically searches for these workspaces, compares them with the primary project, preserves eligible recovery sources, and records the evidence needed to determine the actual latest development state.

It also creates the project source ZIP and the handoff ZIP automatically. Project files are archived according to the exclusion rules defined in `script-settings.json`. The continuation prompt is generated only after the real archive names are known, then the handoff ZIP is refreshed so the generated prompt and archive-comparison reports are included in the final bundle.

### Key features

* Automatically discover Codex sessions related to the project
* Preserve related raw Codex session files and readable transcripts
* Recover the latest user prompt and the primary multi-item implementation request
* Reconstruct recent user-prompt history
* Extract and preserve recoverable `apply_patch` operations
* Automatically discover staging, worktree, scratch, temp, backup, shadow, and similar external workspaces
* Search outside the main project directory, including relevant parent and grandparent locations
* Compare external workspaces against the primary source tree
* Detect newer or additional code left outside the expected project directory
* Generate external-workspace diff reports
* Preserve recovery evidence separately from concise AI handoff context
* Detect requested features and provide implementation-evidence signals without falsely treating them as proof of completion
* Help the next AI classify work as completed, partially completed, skipped/not started, or uncertain
* Automatically create the project source ZIP
* Automatically create and refresh the timestamped `AI_HANDOFF_BUNDLE_<timestamp>.zip`
* Generate continuation prompts using the actual generated archive names
* Support Turkish and English continuation prompts through `script-settings.json`
* Automatically create `script-settings.json` when it does not exist
* Support global folder and file exclusion patterns
* Apply exclusion rules to project scans, archive creation, ZIP comparison, and external-workspace discovery where appropriate
* Detect archive omissions without incorrectly treating configured exclusions as lost source files
* Save a settings snapshot inside the handoff bundle so the next AI can see which files or directories were intentionally excluded
* Keep large forensic session data separate from the main handoff instructions to reduce unnecessary AI context/token usage
* Avoid silently producing partial external-workspace recovery copies

### Recovery model

The generated handoff bundle may contain multiple independent recovery sources:

```text
Main project source
External staging/worktree copies
Recovered apply_patch operations
Codex transcripts
Raw Codex sessions
Workspace diff reports
Prompt history
Feature evidence
Archive omission reports
```

The next AI is explicitly instructed to cross-check these sources before deciding what was completed, what is missing, and which working tree represents the most advanced state.

The goal is not merely to preserve conversation history or make the project build again. The goal is to recover the most advanced development state reached by the previous coding agent as completely as possible, preserve already completed work, and safely continue the unfinished task.

---

## Türkçe

Yarım kalan Codex/AI geliştirme oturumlarını kurtarmak ve başka bir coding agent'a güvenli şekilde devretmek için geliştirilmiş bir PowerShell recovery ve handoff aracıdır.

Araç; mevcut proje durumunu, ilgili Codex session kayıtlarını, kullanıcı promptlarını, `apply_patch` geçmişini, harici çalışma alanlarını, kaynak kod farklarını ve diğer kurtarma kanıtlarını bir araya getirerek taşınabilir bir handoff paketi oluşturur.

Basit bir konuşma geçmişi aktarımından farklı olarak ana proje klasörünün her zaman en güncel kaynak olduğunu varsaymaz. Codex daha yeni değişiklikleri staging, worktree, scratch, temp, backup, shadow veya benzeri harici çalışma alanlarında bırakmış olabilir. Araç bu alanları otomatik olarak araştırır, ana projeyle karşılaştırır, uygun recovery kaynaklarını korur ve gerçek son geliştirme durumunun belirlenebilmesi için gerekli kanıtları raporlar.

Proje kaynak ZIP'i ve handoff ZIP'i de araç tarafından otomatik oluşturulur. Proje arşivine dahil edilecek dosyalar `script-settings.json` içindeki exclude kurallarına göre belirlenir. Continuation prompt, gerçek ZIP dosya adları oluştuktan sonra üretilir. Son olarak handoff ZIP yeniden oluşturularak prompt ve arşiv karşılaştırma raporlarının da final pakete dahil edilmesi sağlanır.

### Temel özellikler

* Projeyle ilişkili Codex session kayıtlarını otomatik keşfetme
* İlgili raw Codex session dosyalarını ve okunabilir transcript'leri koruma
* Son kullanıcı promptunu ve ana çok maddeli geliştirme talebini çıkarma
* Yakın kullanıcı prompt geçmişini yeniden oluşturma
* Kurtarılabilir `apply_patch` işlemlerini çıkarma ve saklama
* Staging, worktree, scratch, temp, backup, shadow ve benzeri harici çalışma alanlarını otomatik keşfetme
* Ana proje klasörünün dışındaki ilgili parent ve grandparent alanlarını da tarama
* Harici workspace'leri ana proje ile karşılaştırma
* Beklenen proje klasörü dışında bırakılmış daha yeni veya ek kodları tespit etme
* External workspace diff raporları oluşturma
* Büyük forensic recovery verilerini kısa AI handoff bağlamından ayrı tutma
* Kullanıcı tarafından istenen özellikleri çıkarıp implementation sinyalleri üretme
* Implementation sinyalini yanlışlıkla "özellik tamamlandı" kanıtı olarak değerlendirmeme
* Devralan AI'ın işleri tamamlanmış, kısmi, başlanmamış/atlanmış veya belirsiz olarak sınıflandırmasını kolaylaştırma
* Proje kaynak ZIP'ini otomatik oluşturma
* Timestamp içeren `AI_HANDOFF_BUNDLE_<timestamp>.zip` dosyasını otomatik oluşturma ve final aşamada yenileme
* Gerçek oluşturulan ZIP adlarını kullanarak dinamik continuation prompt üretme
* `script-settings.json` üzerinden Türkçe veya İngilizce continuation prompt seçme
* `script-settings.json` bulunmuyorsa varsayılan ayarlarla otomatik oluşturma
* Global folder ve file exclude pattern desteği
* Exclude kurallarını proje taraması, ZIP oluşturma, ZIP karşılaştırması ve uygun external-workspace keşif işlemlerinde kullanma
* Ayarlarda exclude edilmiş öğeleri yanlışlıkla "ZIP'ten kaybolmuş kaynak kod" olarak raporlamama
* Kullanılan ayarların snapshot'ını handoff bundle içine ekleme
* Devralan AI'ın hangi dosya/klasörlerin bilinçli olarak işlem dışı bırakıldığını görebilmesini sağlama
* Raw session verilerini gerektiğinde başvurulacak ayrı forensic kaynak olarak saklayarak gereksiz AI context/token kullanımını azaltma
* Harici workspace recovery işleminde sessizce yarım kopya üretmekten kaçınma

### Recovery modeli

Oluşturulan handoff bundle birden fazla bağımsız kurtarma kaynağı içerebilir:

```text
Ana proje kaynak kodu
Harici staging/worktree kopyaları
Kurtarılmış apply_patch işlemleri
Codex transcript'leri
Raw Codex session kayıtları
Workspace diff raporları
Prompt geçmişi
Feature evidence raporları
Archive omission raporları
```

Devralan AI'a, bir özelliğin tamamlandığına veya bir dosyanın en güncel sürüm olduğuna karar vermeden önce bu kaynakları çapraz kontrol etmesi açıkça söylenir.

Amaç yalnızca konuşma geçmişini saklamak veya projeyi tekrar derlenebilir hale getirmek değildir. Amaç, önceki coding agent'ın ulaşmış olduğu en ileri geliştirme durumunu mümkün olduğunca eksiksiz kurtarmak, tamamlanmış işleri kaybetmemek ve yarım kalan göreve güvenli şekilde devam edilmesini sağlamaktır.
