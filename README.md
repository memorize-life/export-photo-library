# export-photo-library

The goal of this project is to export macOS Photo Library preserving as much metadata as possible as directory and file names.

## How to run

To build and run the program, use Xcode.
To specify where to export photos and videos, set a destination directory as the first argument of the program.
The destination directory must not exist.

The program is tested using Xcode version 11.4.1 on macOS version 10.15.3.

## How it works

First, the program uses the [Media Library](https://developer.apple.com/documentation/medialibrary) framework to load your collections of photos and videos from the System Photo Library.
Then it copies photos and videos to the destination directory and creates symbolic links.

See the following example of the directory tree that the program yields:

```
.
├── Albums
│   ├── Backstage
│   ├── Live\ Photos
│   ├── Screenshots
│   ├── Selfies
│   └── Videos
├── Collections
│   ├── 1\ January\ 1980
│   ├── 1–28\ July\ 2018
│   └── 30\ August\ 2020
├── Derivatives
│   ├── 0
│   ├── 1
│   ├── 2
│   ├── 3
│   ├── 4
│   ├── 5
│   ├── 6
│   ├── 7
│   ├── 8
│   ├── 9
│   ├── A
│   ├── B
│   ├── C
│   ├── D
│   ├── E
│   └── F
├── Moments
│   ├── Chelyabinsk,\ 28\ July\ 2018
│   └── Turgoyak,\ 30\ August\ 2020
├── Originals
│   ├── 0
│   ├── 1
│   ├── 2
│   ├── 3
│   ├── 4
│   ├── 5
│   ├── 6
│   ├── 7
│   ├── 8
│   ├── 9
│   ├── A
│   ├── B
│   ├── C
│   ├── D
│   ├── E
│   └── F
├── People
│   ├── Elisey\ Zanko
│   └── London Elektricity
├── Shared
│   ├── Birthday\ party
│   └── Small\ gathering
└── Years
    ├── 1980
    ├── 2018
    └── 2020
```

`Originals` and `Derivatives` contain copies of photos and videos from your Photo Library.
Other directories (for example, `Albums` or `People`) contain symbolic links to the files located in either `Originals` or `Derivatives`.
Symbolic links are used to avoid having multiple copies of the same file and save disk space.

## Known issues

The program has the following main drawbacks:

* **Doesn't export photos and videos from iCloud**

    For example, the program doesn't export shared albums from iCloud.
    It also doesn't download full-resolution photos and videos from iCloud.
    But, only if the **Optimise Mac Storage** option is enabled in the Photos app.
    Otherwise, if the option is disabled, original photos and videos are stored on your Mac and therefore are exported.

* **Uses deprecated Media Library framework**

    The framework will be removed in macOS version 10.16.
    Therefore, the program won't work on that version of macOS.

## Prior art

The following list contains a few projects that help export macOS Photo Library preserving metadata:

* **[abentele/PhotosExporter](https://github.com/abentele/PhotosExporter)**

    Uses the Media Library framework.
    Therefore, has similar issues (described above).

* **[RhetTbull/osxphotos](https://github.com/RhetTbull/osxphotos)**

    Works by creating a copy of the [SQLite](https://www.sqlite.org) database that the Photos app uses to store data about the Photo Library.
    The program will likely break if Apple changes the database format.
    While copying the SQLite database is a bit clumsy, it allows osxphotos to provide access to all available metadata.

## License

This project is licensed under the GPLv3 License–see the [LICENSE](LICENSE) file for details.