const fs = require("fs");
const https = require("https");
const path = require("path");

const root = path.resolve(__dirname, "..");
const cardsPath = path.join(root, "data", "cards.json");
const sourceDir = path.join(root, "data", "kanjivg");
const outputPath = path.join(root, "generated", "kanji-data.json");
const browserOutputPath = path.join(root, "generated", "kanji-data.js");
const kanjiVgBaseUrl = "https://raw.githubusercontent.com/KanjiVG/kanjivg/master/kanji";

main().catch((error) => {
    console.error(error.message);
    process.exitCode = 1;
});

async function main() {
    ensureDirectories();

    const cards = JSON.parse(fs.readFileSync(cardsPath, "utf8"));

    for (const card of cards) {
        await downloadKanjiVgIfMissing(card.kanji);
    }

    const kanjiData = cards.map((card) => {
        const fileName = fileNameForKanji(card.kanji);
        const svgPath = path.join(sourceDir, fileName);
        const svg = fs.readFileSync(svgPath, "utf8");
        const strokes = extractStrokes(svg);

        return {
            ...card,
            source: {
                name: "KanjiVG",
                file: fileName,
                license: "Creative Commons Attribution-Share Alike 3.0"
            },
            strokes
        };
    });

    fs.writeFileSync(outputPath, `${JSON.stringify(kanjiData, null, 2)}\n`);
    fs.writeFileSync(browserOutputPath, `window.KANJI_DATA = ${JSON.stringify(kanjiData, null, 2)};\n`);
    console.log(`Wrote ${kanjiData.length} kanji to ${outputPath}`);
}

function ensureDirectories() {
    fs.mkdirSync(sourceDir, { recursive: true });
    fs.mkdirSync(path.dirname(outputPath), { recursive: true });
}

async function downloadKanjiVgIfMissing(kanji) {
    const fileName = fileNameForKanji(kanji);
    const svgPath = path.join(sourceDir, fileName);

    if (fs.existsSync(svgPath)) {
        console.log(`Already have ${fileName}`);
        return;
    }

    const url = `${kanjiVgBaseUrl}/${fileName}`;
    console.log(`Downloading ${url}`);
    const svg = await downloadText(url);

    if (!svg.includes("<svg")) {
        throw new Error(`Downloaded file does not look like SVG: ${url}`);
    }

    fs.writeFileSync(svgPath, svg);
}

function downloadText(url) {
    return new Promise((resolve, reject) => {
        https.get(url, (response) => {
            if (response.statusCode !== 200) {
                response.resume();
                reject(new Error(`Request failed with ${response.statusCode}: ${url}`));
                return;
            }

            response.setEncoding("utf8");
            let body = "";
            response.on("data", (chunk) => {
                body += chunk;
            });
            response.on("end", () => {
                resolve(body);
            });
        }).on("error", reject);
    });
}

function fileNameForKanji(kanji) {
    return `${kanji.codePointAt(0).toString(16).padStart(5, "0")}.svg`;
}

function extractStrokes(svg) {
    return [...svg.matchAll(/<path\b[^>]*\bd="([^"]+)"/g)].map((match, index) => {
        const pathData = decodeXml(match[1]);
        const points = extractPathPoints(pathData);

        return {
            order: index + 1,
            path: pathData,
            start: points[0],
            end: points[points.length - 1],
            axis: axisFor(points),
            bounds: boundsFor(points)
        };
    });
}

function extractPathPoints(pathData) {
    const commandPattern = /([MLCSQTAZHVZmlcsqtazhvz])([^MLCSQTAZHVZmlcsqtazhvz]*)/g;
    const points = [];
    let current = [0, 0];
    let match;

    while ((match = commandPattern.exec(pathData)) !== null) {
        const command = match[1];
        const numbers = [...match[2].matchAll(/-?\d+(?:\.\d+)?/g)].map((numberMatch) => Number(numberMatch[0]));

        if (command === "M" || command === "L") {
            for (let index = 0; index < numbers.length - 1; index += 2) {
                current = [numbers[index], numbers[index + 1]];
                points.push(current);
            }
        } else if (command === "m" || command === "l") {
            for (let index = 0; index < numbers.length - 1; index += 2) {
                current = [current[0] + numbers[index], current[1] + numbers[index + 1]];
                points.push(current);
            }
        } else if (command === "C") {
            for (let index = 0; index < numbers.length - 5; index += 6) {
                current = [numbers[index + 4], numbers[index + 5]];
                points.push(current);
            }
        } else if (command === "c") {
            for (let index = 0; index < numbers.length - 5; index += 6) {
                current = [current[0] + numbers[index + 4], current[1] + numbers[index + 5]];
                points.push(current);
            }
        }
    }

    return points;
}

function axisFor(points) {
    const bounds = boundsFor(points);
    const width = bounds.maxX - bounds.minX;
    const height = bounds.maxY - bounds.minY;

    if (width > height * 1.5) {
        return "horizontal";
    }

    if (height > width * 1.5) {
        return "vertical";
    }

    return "corner";
}

function boundsFor(points) {
    return points.reduce((bounds, point) => ({
        minX: Math.min(bounds.minX, point[0]),
        minY: Math.min(bounds.minY, point[1]),
        maxX: Math.max(bounds.maxX, point[0]),
        maxY: Math.max(bounds.maxY, point[1])
    }), {
        minX: Number.POSITIVE_INFINITY,
        minY: Number.POSITIVE_INFINITY,
        maxX: Number.NEGATIVE_INFINITY,
        maxY: Number.NEGATIVE_INFINITY
    });
}

function decodeXml(value) {
    return value
        .replaceAll("&quot;", "\"")
        .replaceAll("&apos;", "'")
        .replaceAll("&lt;", "<")
        .replaceAll("&gt;", ">")
        .replaceAll("&amp;", "&");
}
