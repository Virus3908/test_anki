const CANONICAL_SIZE = 109;

const canvas = document.getElementById("drawing-board");
const context = canvas.getContext("2d");
const promptMeaning = document.getElementById("prompt-meaning");
const answer = document.getElementById("answer");
const answerKanjiLarge = document.getElementById("answer-kanji-large");
const answerKanji = document.getElementById("answer-kanji");
const answerOnyomi = document.getElementById("answer-onyomi");
const answerKunyomi = document.getElementById("answer-kunyomi");
const examplesList = document.getElementById("examples-list");
const feedbackList = document.getElementById("feedback-list");
const strokeDemoSvg = document.getElementById("stroke-demo-svg");
const undoButton = document.getElementById("undo-button");
const clearButton = document.getElementById("clear-button");
const checkButton = document.getElementById("check-button");
const flipButton = document.getElementById("flip-button");

const kanjiCard = window.KANJI_DATA[0];
const expectedStrokes = kanjiCard.strokes;

let strokes = [];
let currentStroke = null;
let drawing = false;

renderCardData();
resizeCanvasBackingStore();
drawAllStrokes();

window.addEventListener("resize", () => {
    resizeCanvasBackingStore();
    drawAllStrokes();
});

canvas.addEventListener("pointerdown", startStroke);
canvas.addEventListener("pointermove", continueStroke);
canvas.addEventListener("pointerup", finishStroke);
canvas.addEventListener("pointercancel", finishStroke);
canvas.addEventListener("pointerleave", finishStroke);

undoButton.addEventListener("click", () => {
    strokes.pop();
    drawAllStrokes();
    renderFeedback(false);
});

clearButton.addEventListener("click", () => {
    strokes = [];
    currentStroke = null;
    drawAllStrokes();
    feedbackList.replaceChildren();
    answer.hidden = true;
});

checkButton.addEventListener("click", () => {
    renderFeedback(true);
});

flipButton.addEventListener("click", () => {
    renderFeedback(true);
    answer.hidden = false;
});

function renderCardData() {
    promptMeaning.textContent = kanjiCard.meanings.join(", ");
    answerKanjiLarge.textContent = kanjiCard.kanji;
    answerKanji.textContent = kanjiCard.kanji;
    answerOnyomi.textContent = `Онъёми: ${kanjiCard.onyomi.join(", ")}`;
    answerKunyomi.textContent = `Кунъёми: ${kanjiCard.kunyomi.join(", ")}`;

    for (const example of kanjiCard.examples) {
        const item = document.createElement("li");
        item.innerHTML = `<strong>${example.word}</strong> (${example.reading}) — ${example.meaning}`;
        examplesList.appendChild(item);
    }

    for (const stroke of expectedStrokes) {
        const path = document.createElementNS("http://www.w3.org/2000/svg", "path");
        path.setAttribute("d", stroke.path);
        strokeDemoSvg.appendChild(path);

        const number = document.createElementNS("http://www.w3.org/2000/svg", "text");
        number.setAttribute("x", stroke.start[0] - 5);
        number.setAttribute("y", stroke.start[1] - 4);
        number.textContent = stroke.order;
        strokeDemoSvg.appendChild(number);
    }
}

function resizeCanvasBackingStore() {
    const rect = canvas.getBoundingClientRect();
    const pixelScale = window.devicePixelRatio || 1;
    const coordinateScale = rect.width / CANONICAL_SIZE;

    canvas.width = Math.round(rect.width * pixelScale);
    canvas.height = Math.round(rect.height * pixelScale);
    context.setTransform(pixelScale * coordinateScale, 0, 0, pixelScale * coordinateScale, 0, 0);
}

function startStroke(event) {
    drawing = true;
    canvas.setPointerCapture(event.pointerId);
    currentStroke = [pointFromEvent(event)];
    drawAllStrokes();
}

function continueStroke(event) {
    if (!drawing || !currentStroke) {
        return;
    }

    currentStroke.push(pointFromEvent(event));
    drawAllStrokes();
}

function finishStroke() {
    if (!drawing || !currentStroke) {
        return;
    }

    drawing = false;

    if (currentStroke.length > 2) {
        strokes.push(simplifyStroke(currentStroke));
    }

    currentStroke = null;
    drawAllStrokes();
}

function pointFromEvent(event) {
    const rect = canvas.getBoundingClientRect();
    return [
        ((event.clientX - rect.left) / rect.width) * CANONICAL_SIZE,
        ((event.clientY - rect.top) / rect.height) * CANONICAL_SIZE
    ];
}

function simplifyStroke(points) {
    const simplified = [];

    for (let index = 0; index < points.length; index += 3) {
        simplified.push(points[index]);
    }

    if (simplified[simplified.length - 1] !== points[points.length - 1]) {
        simplified.push(points[points.length - 1]);
    }

    return simplified;
}

function drawAllStrokes() {
    context.clearRect(0, 0, CANONICAL_SIZE, CANONICAL_SIZE);

    for (const stroke of strokes) {
        drawStroke(stroke, "#20282b", 3.5);
    }

    if (currentStroke) {
        drawStroke(currentStroke, "#245d63", 3.5);
    }
}

function drawStroke(points, color, width) {
    if (points.length < 2) {
        return;
    }

    context.save();
    context.strokeStyle = color;
    context.lineWidth = width;
    context.lineCap = "round";
    context.lineJoin = "round";
    context.beginPath();
    context.moveTo(points[0][0], points[0][1]);

    for (const point of points.slice(1)) {
        context.lineTo(point[0], point[1]);
    }

    context.stroke();
    context.restore();
}

function renderFeedback(showAnswer) {
    const results = evaluateStrokes();
    feedbackList.replaceChildren();

    for (const result of results) {
        const item = document.createElement("li");
        item.textContent = result;
        feedbackList.appendChild(item);
    }

    if (showAnswer) {
        answer.hidden = false;
    }
}

function evaluateStrokes() {
    const messages = [];

    if (strokes.length === 0) {
        return ["Пока нет штрихов. Нарисуй кандзи, потом нажми «Проверить»."];
    }

    if (strokes.length !== expectedStrokes.length) {
        messages.push(`Нужно ${expectedStrokes.length} штриха, сейчас распознано ${strokes.length}.`);
    } else {
        messages.push("Количество штрихов похоже на правильное.");
    }

    expectedStrokes.forEach((expected, index) => {
        const actual = strokes[index];

        if (!actual) {
            messages.push(`Штрих ${index + 1}: не найден.`);
            return;
        }

        const verdict = evaluateStroke(actual, expected);
        messages.push(`Штрих ${index + 1}: ${verdict}`);
    });

    if (strokes.length > expectedStrokes.length) {
        messages.push(`Есть лишние штрихи после ${expectedStrokes.length}-го.`);
    }

    return messages;
}

function evaluateStroke(points, expected) {
    const start = points[0];
    const end = points[points.length - 1];
    const forwardDistance = distance(start, expected.start) + distance(end, expected.end);
    const reverseDistance = distance(start, expected.end) + distance(end, expected.start);
    const directionOk = forwardDistance <= reverseDistance;
    const shapeOk = strokeShapeLooksRight(points, expected.axis);
    const placementOk = forwardDistance < 34;

    if (directionOk && shapeOk && placementOk) {
        return "хорошо.";
    }

    const problems = [];

    if (!directionOk) {
        problems.push("направление похоже обратное");
    }

    if (!shapeOk) {
        problems.push("форма штриха отличается");
    }

    if (!placementOk) {
        problems.push("штрих далеко от нужного места");
    }

    return `${problems.join(", ")}.`;
}

function strokeShapeLooksRight(points, axis) {
    const box = boundingBox(points);
    const width = box.maxX - box.minX;
    const height = box.maxY - box.minY;

    if (axis === "horizontal") {
        return width > height * 1.5;
    }

    if (axis === "vertical") {
        return height > width * 1.5;
    }

    return width > 18 && height > 24;
}

function boundingBox(points) {
    return points.reduce((box, point) => ({
        minX: Math.min(box.minX, point[0]),
        minY: Math.min(box.minY, point[1]),
        maxX: Math.max(box.maxX, point[0]),
        maxY: Math.max(box.maxY, point[1])
    }), {
        minX: Number.POSITIVE_INFINITY,
        minY: Number.POSITIVE_INFINITY,
        maxX: Number.NEGATIVE_INFINITY,
        maxY: Number.NEGATIVE_INFINITY
    });
}

function distance(a, b) {
    return Math.hypot(a[0] - b[0], a[1] - b[1]);
}
