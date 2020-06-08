# ickabog-ebook

Generates ebooks for The Ickabog by J.K Rowling. Original text from https://www.theickabog.com/

Initially based off of https://github.com/captn3m0/ickabog-ebook but adds:
- Support for other languages
- Fetches the list of chapters from the website itslef
- Uses kindlegen to convert to mobi
- Docker recipe to run this without hassle

## Dependencies:

- `wget`
- [`pup`](https://github.com/ericchiang/pup)
- [`pandoc`](https://pandoc.org/)
- [`qpdf`]
- [`kindlegen`](https://www.amazon.com/gp/feature.html?ie=UTF8&docId=1000765211)

Or you can build a container using the Dockerfile (look at the volume section to get your fresh PDF, Epub and MOBI copies).

## How to run

### Manually

Install the dependencies then run

`./generate.sh`

You should have `ickabog.epub`, `ickabog.mobi` and `ickabog.pdf` in your directory after the script finishes.

### Using Docker

`cd` to the directory containing the `Dockerfile` recipe, then run `docker build -t ickabook .`

Once the build is complete, you can run `docker run -it -v /your/ouput/dir:/data/out ickabook`

`/your/output/dir` should be a preexisting dir where you want to find the aforementionned files after the container has run.

## Credits

The cover art is [Avanyu](http://edan.si.edu/saam/id/object/1979.144.85) by Julian Martinez. Used under Creative Commons license.

> Julian Martinez, Avanyu, ca. 1923, watercolor, ink, and pencil on paper, Smithsonian American Art Museum, Corbin-Henderson Collection, gift of Alice H. Rossin, 1979.144.85

## License

The little code in this repository is licensed under the [MIT License](https://nemo.mit-license.org/). See LICENSE file for details.
