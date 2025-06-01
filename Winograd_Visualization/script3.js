// Winograd transformation matrices
const B = [
    [1, 0, -1, 0],
    [0, 1, 1, 0],
    [0, -1, 1, 0],
    [0, 1, 0, -1]
];

const G = [
    [1, 0, 0],
    [0.5, 0.5, 0.5],
    [0.5, -0.5, 0.5],
    [0, 0, 1]
];

const A = [
    [1, 1, 1, 0],
    [0, 1, -1, -1]
];

let currentStep = 0;
const steps = [
    "Step 1: Original input (4x4) and filter (3x3)",
    "Step 2: View transformation matrices (B, G, A)",
    "Step 3: Transform input using B matrices",
    "Step 4: Transform filter using G matrices",
    "Step 5: Element-wise multiplication",
    "Step 6: Final output after inverse transform using A",
    "Step 7: Direct convolution animation (for comparison)"
];

const stepDescriptions = [
    "We start with an input matrix of size 4x4 and a filter (kernel) of size 3x3. The Winograd algorithm will compute a 2x2 output using matrix transformations to reduce multiplications.",

    "B matrix (4x4): Used to transform the input tile<br>G matrix (4x3): Used to transform the filter<br>A matrix (2x4): Used for the inverse transform<br><br>These matrices are carefully designed to minimize the number of multiplications needed.",

    "To transform the input, we compute:<br><div class='formula'>U = B × Input × B<sup>T</sup></div>This transforms the original input into a form that allows efficient computation.",

    "Similarly, we transform the filter with:<br><div class='formula'>V = G × Filter × G<sup>T</sup></div>This prepares the filter for element-wise multiplication rather than traditional convolution.",

    "Instead of sliding the filter and computing sums of products, we simply multiply the transformed matrices element-wise:<br><div class='formula'>M = U ⊙ V</div>where ⊙ represents element-wise multiplication. This reduces the number of multiplications needed!",

    "Finally, we compute the output with:<br><div class='formula'>Output = A × M × A<sup>T</sup></div>This transforms our intermediate result back to the desired output space.",

    "For comparison, here's how traditional convolution would slide the 3x3 kernel over the 4x4 input, computing each output element with 9 multiplications and additions."
];

let input = [];
let filter = [];
let transformedInput = [];
let transformedFilter = [];
let elementwiseProduct = [];
let output = [];
let animationStep = 0;
let animationInterval;
let transformationAnimationStep = 0;
let transformationInterval;
let transformationActive = false;

// Function to create a matrix element
function createMatrixElement(rows, cols, elementId, className) {
    const matrixDiv = document.getElementById(elementId);
    if (!matrixDiv) return; // Safety check
    
    matrixDiv.style.gridTemplateColumns = `repeat(${cols}, 35px)`;
    matrixDiv.innerHTML = '';

    for (let i = 0; i < rows; i++) {
        for (let j = 0; j < cols; j++) {
            const cell = document.createElement('div');
            cell.className = `cell ${className}`;
            cell.dataset.row = i;
            cell.dataset.col = j;
            matrixDiv.appendChild(cell);
        }
    }
}

// Function to fill a matrix with data
function fillMatrix(matrixData, elementId, className, randomize = false) {
    const matrixDiv = document.getElementById(elementId);
    if (!matrixDiv) return matrixData; // Safety check

    // Clear existing content
    matrixDiv.innerHTML = '';

    // Set the grid layout based on matrix column count
    const numCols = matrixData[0].length;
    matrixDiv.style.display = 'grid';
    matrixDiv.style.gridTemplateColumns = `repeat(${numCols}, 35px)`;
    matrixDiv.style.gap = '0';

    for (let i = 0; i < matrixData.length; i++) {
        for (let j = 0; j < matrixData[i].length; j++) {
            let value = matrixData[i][j];

            if (randomize) {
                if (className === 'input') {
                    value = Math.floor(Math.random() * 5);
                    matrixData[i][j] = value;
                } else if (className === 'filter') {
                    value = Math.floor(Math.random() * 3);
                    matrixData[i][j] = value;
                }
            }

            const cell = document.createElement('div');
            cell.className = `cell ${className}`;
            cell.textContent = value;
            matrixDiv.appendChild(cell);
        }
    }

    return matrixData;
}

// Matrix multiplication with precision handling
function matrixMultiply(a, b) {
    const result = [];
    for (let i = 0; i < a.length; i++) {
        result[i] = [];
        for (let j = 0; j < b[0].length; j++) {
            let sum = 0;
            for (let k = 0; k < a[0].length; k++) {
                sum += a[i][k] * b[k][j];
            }
            result[i][j] = Math.round(sum * 1000) / 1000;
        }
    }
    return result;
}

// Matrix transpose
function transpose(m) {
    return m[0].map((_, i) => m.map(row => row[i]));
}

// Function to set up all matrices
function setupMatrices() {
    // Define initial matrices
    input = [
        [1, 2, 3, 4],
        [5, 6, 7, 8],
        [9, 10, 11, 12],
        [13, 14, 15, 16]
    ];
    
    filter = [
        [1, 2, 1],
        [0, 1, 0],
        [1, 0, 1]
    ];
    
    // Create and fill original matrices
    createMatrixElement(4, 4, 'inputMatrix', 'input');
    createMatrixElement(3, 3, 'filterMatrix', 'filter');
    createMatrixElement(2, 2, 'outputMatrix', 'output');
    
    fillMatrix(input, 'inputMatrix', 'input');
    fillMatrix(filter, 'filterMatrix', 'filter');
    fillMatrix([[0,0],[0,0]], 'outputMatrix', 'output');
    
    // Create and fill transformation matrices
    createMatrixElement(4, 4, 'bMatrix', 'transform');
    createMatrixElement(4, 3, 'gMatrix', 'transform');
    createMatrixElement(2, 4, 'aMatrix', 'transform');
    
    fillMatrix(B, 'bMatrix', 'transform');
    fillMatrix(G, 'gMatrix', 'transform');
    fillMatrix(A, 'aMatrix', 'transform');
    
    // Create duplicate matrices for different sections
    createMatrixElement(4, 4, 'inputMatrix2', 'input');
    createMatrixElement(4, 4, 'bMatrix2', 'transform');
    createMatrixElement(4, 4, 'bMatrixT', 'transform');
    createMatrixElement(4, 4, 'interInputBT', 'transform');
    createMatrixElement(4, 4, 'transformedInputMatrix', 'input');
    
    createMatrixElement(3, 3, 'filterMatrix2', 'filter');
    createMatrixElement(4, 3, 'gMatrix2', 'transform');
    createMatrixElement(3, 4, 'gMatrixT', 'transform');
    createMatrixElement(3, 4, 'interFilterGT', 'transform');
    createMatrixElement(4, 4, 'transformedFilterMatrix', 'filter');
    
    createMatrixElement(4, 4, 'transformedInputMatrix2', 'input');
    createMatrixElement(4, 4, 'transformedFilterMatrix2', 'filter');
    createMatrixElement(4, 4, 'elementwiseProductMatrix', 'output');
    
    createMatrixElement(4, 4, 'elementwiseProductMatrix2', 'output');
    createMatrixElement(2, 4, 'aMatrix2', 'transform');
    createMatrixElement(4, 2, 'aMatrixT', 'transform');
    createMatrixElement(2, 4, 'interAProduct', 'transform');
    createMatrixElement(2, 2, 'outputMatrix2', 'output');
    
    createMatrixElement(4, 4, 'animInputMatrix', 'input');
    createMatrixElement(2, 2, 'animOutputMatrix', 'output');
    
    // Fill duplicate matrices
    fillMatrix(input, 'inputMatrix2', 'input');
    fillMatrix(B, 'bMatrix2', 'transform');
    fillMatrix(transpose(B), 'bMatrixT', 'transform');
    
    fillMatrix(filter, 'filterMatrix2', 'filter');
    fillMatrix(G, 'gMatrix2', 'transform');
    fillMatrix(transpose(G), 'gMatrixT', 'transform');
    
    fillMatrix(A, 'aMatrix2', 'transform');
    fillMatrix(transpose(A), 'aMatrixT', 'transform');
    
    fillMatrix(input, 'animInputMatrix', 'input');
    fillMatrix([[0, 0], [0, 0]], 'animOutputMatrix', 'output');
}

// Reset function
function reset() {
    clearInterval(animationInterval);
    clearInterval(transformationInterval);
    currentStep = 0;
    animationStep = 0;
    transformationAnimationStep = 0;
    transformationActive = false;
    
    // Hide animation controls
    document.getElementById('animationControls').classList.add('hidden');
    document.getElementById('transformationStatus').textContent = '';
    
    // Show only the first section
    document.querySelectorAll('.section').forEach((section, index) => {
        if (index === 0) {
            section.classList.remove('hidden');
        } else {
            section.classList.add('hidden');
        }
    });
    
    // Update step buttons
    document.querySelectorAll('.step-btn').forEach((btn, index) => {
        if (index === 0) {
            btn.classList.add('active');
        } else {
            btn.classList.remove('active');
        }
    });
    
    setupMatrices();
    updateExplanation();
}

// Update explanation text
function updateExplanation() {
    document.getElementById('explanation').textContent = steps[currentStep];
    document.getElementById('stepDetail').innerHTML = stepDescriptions[currentStep];
}

// Previous step function
function prevStep() {
    clearInterval(animationInterval);
    clearInterval(transformationInterval);
    transformationActive = false;
    document.getElementById('transformationStatus').textContent = '';
    
    if (currentStep > 0) {
        currentStep--;
        updateStepDisplay();
    }
}

// Next step function
function nextStep() {
    clearInterval(animationInterval);
    clearInterval(transformationInterval);
    transformationActive = false;
    document.getElementById('transformationStatus').textContent = '';
    
    if (currentStep < steps.length - 1) {
        currentStep++;
        updateStepDisplay();
    }
}

// Update display based on current step
function updateStepDisplay() {
    updateExplanation();
    
    // Hide all sections
    document.querySelectorAll('.section').forEach(section => {
        section.classList.add('hidden');
    });
    
    // Update step buttons
    document.querySelectorAll('.step-btn').forEach((btn, index) => {
        if (index === currentStep) {
            btn.classList.add('active');
        } else {
            btn.classList.remove('active');
        }
    });
    
    // Show current section
    document.getElementById(`section-${currentStep}`).classList.remove('hidden');
    
    // Show/hide animation controls
    if (currentStep >= 2 && currentStep <= 5) {
        document.getElementById('animationControls').classList.remove('hidden');
    } else {
        document.getElementById('animationControls').classList.add('hidden');
    }
    
    // Perform step-specific calculations
    switch (currentStep) {
        case 2: // Transform input using B
            const BT = transpose(B);
            const inputBT = matrixMultiply(input, BT);
            transformedInput = matrixMultiply(B, inputBT);
            
            fillMatrix(inputBT, 'interInputBT', 'transform');
            fillMatrix(transformedInput, 'transformedInputMatrix', 'input');
            break;
            
        case 3: // Transform filter using G
            const GT = transpose(G);
            const filterGT = matrixMultiply(filter, GT);
            transformedFilter = matrixMultiply(G, filterGT);
            
            fillMatrix(filterGT, 'interFilterGT', 'transform');
            fillMatrix(transformedFilter, 'transformedFilterMatrix', 'filter');
            
            // Also update the input transform matrices for continuity
            fillMatrix(transformedInput, 'transformedInputMatrix2', 'input');
            break;
            
        case 4: // Element-wise multiplication
            elementwiseProduct = [];
            for (let i = 0; i < 4; i++) {
                elementwiseProduct[i] = [];
                for (let j = 0; j < 4; j++) {
                    const val = transformedInput[i][j] * transformedFilter[i][j];
                    elementwiseProduct[i][j] = val;
                }
            }
            
            fillMatrix(transformedInput, 'transformedInputMatrix2', 'input');
            fillMatrix(transformedFilter, 'transformedFilterMatrix2', 'filter');
            fillMatrix(elementwiseProduct, 'elementwiseProductMatrix', 'output');
            fillMatrix(elementwiseProduct, 'elementwiseProductMatrix2', 'output');
            break;
            
        case 5: // Final output calculation
            const AT = transpose(A);
            // const AM = matrixMultiply(A, elementwiseProduct);
            // output = matrixMultiply(AM, AT);

            const MAT = matrixMultiply(elementwiseProduct, AT);
            output = matrixMultiply(A, MAT);
            
            // Round final output values
            const roundedOutput = output.map(row =>
                row.map(val => Math.round(val * 1000) / 1000)
            );
            
            fillMatrix(MAT, 'interAProduct', 'transform');
            fillMatrix(roundedOutput, 'outputMatrix', 'output');
            fillMatrix(roundedOutput, 'outputMatrix2', 'output');
            break;
            
        case 6: // Direct convolution animation
            animationStep = 0;
            startConvolutionAnimation();
            break;
    }
}

// Start animation of transformation
function startTransformationAnimation() {
    if (transformationActive) {
        clearInterval(transformationInterval);
        transformationActive = false;
        document.getElementById('transformationStatus').textContent = 'Animation paused';
        document.getElementById('animateBtn').textContent = 'Resume Animation';
        return;
    }
    
    transformationActive = true;
    document.getElementById('animateBtn').textContent = 'Pause Animation';
    
    switch(currentStep) {
        case 2:
            animateInputTransformation();
            break;
        case 3:
            animateFilterTransformation();
            break;
        case 4:
            animateElementwiseMultiplication();
            break;
        case 5:
            animateInverseTransformation();
            break;
    }
}

// Animate input transformation
function animateInputTransformation() {
    const BT = transpose(B);
    const inputCells = document.getElementById('inputMatrix2').getElementsByClassName('cell');
    const btCells = document.getElementById('bMatrixT').getElementsByClassName('cell');
    const bCells = document.getElementById('bMatrix2').getElementsByClassName('cell');
    const intermediateCells = document.getElementById('interInputBT').getElementsByClassName('cell');
    const resultCells = document.getElementById('transformedInputMatrix').getElementsByClassName('cell');
    
    // Reset all highlights
    Array.from(inputCells).forEach(cell => cell.classList.remove('active'));
    Array.from(btCells).forEach(cell => cell.classList.remove('active'));
    Array.from(bCells).forEach(cell => cell.classList.remove('active'));
    Array.from(intermediateCells).forEach(cell => cell.classList.remove('active'));
    Array.from(resultCells).forEach(cell => cell.classList.remove('active'));
    
    const inputBT = matrixMultiply(input, BT);
    const transformedInput = matrixMultiply(B, inputBT);
    
    let animPhase = 0; // 0: Bᵀ * input, 1: (Bᵀ * input) * B
    let currentRow = 0;
    let currentCol = 0;
    
    transformationAnimationStep = 0;
    document.getElementById('transformationStatus').textContent = 'Animating Bᵀ * input calculation...';
    
    clearInterval(transformationInterval);
    transformationInterval = setInterval(() => {
        if (!transformationActive) return;
        
        // Reset previous highlights
        Array.from(inputCells).forEach(cell => cell.classList.remove('active'));
        Array.from(btCells).forEach(cell => cell.classList.remove('active'));
        Array.from(bCells).forEach(cell => cell.classList.remove('active'));
        Array.from(intermediateCells).forEach(cell => cell.classList.remove('active'));
        Array.from(resultCells).forEach(cell => cell.classList.remove('active'));
        
        if (animPhase === 0) {
            // Highlight cells during the first phase (Bᵀ * input)
            for (let k = 0; k < 4; k++) {
                const btCellIndex = currentRow * 4 + k;
                if (btCells[btCellIndex]) btCells[btCellIndex].classList.add('active');
                
                const inputCellIndex = k * 4 + currentCol;
                if (inputCells[inputCellIndex]) inputCells[inputCellIndex].classList.add('active');
            }
            const intermediateIndex = currentRow * 4 + currentCol;
            if (intermediateCells[intermediateIndex]) intermediateCells[intermediateIndex].classList.add('active');
            
            currentCol++;
            if (currentCol >= 4) {
                currentCol = 0;
                currentRow++;
                if (currentRow >= 4) {
                    // Move to the next phase after completing the first
                    animPhase = 1; 
                    currentRow = 0; // reset row index
                    currentCol = 0; // reset column index
                    document.getElementById('transformationStatus').textContent = 'Animating (Bᵀ * input) * B calculation...';
                }
            }
        } else if (animPhase === 1) {
            // Highlight cells during the second phase ((Bᵀ * input) * B)
            // Highlight current intermediate row
            for (let k = 0; k < 4; k++) {
                intermediateCells[currentRow * 4 + k].classList.add('active');
                // Highlight current B column
                bCells[k * 4 + currentCol].classList.add('active');
            }
            
            // Highlight result cell
            resultCells[currentRow * 4 + currentCol].classList.add('active');
            
            currentCol++;
            if (currentCol >= 4) {
                currentCol = 0;
                currentRow++;
                if (currentRow >= 4) {
                    clearInterval(transformationInterval);
                    transformationActive = false;
                    document.getElementById('transformationStatus').textContent = 'Input transformation complete!';
                    document.getElementById('animateBtn').textContent = 'Animate Again';
                    
                    // Show all results
                    fillMatrix(BT, 'bMatrixT', 'transform');
                    fillMatrix(inputBT, 'interInputBT', 'transform');
                    fillMatrix(transformedInput, 'transformedInputMatrix', 'input');
                }
            }
        }
        
        transformationAnimationStep++;
    }, 500);
}

// Animate filter transformation
function animateFilterTransformation() {
    const GT = transpose(G);
    const filterCells = document.getElementById('filterMatrix2').getElementsByClassName('cell');
    const gCells = document.getElementById('gMatrix2').getElementsByClassName('cell');
    const gtCells = document.getElementById('gMatrixT').getElementsByClassName('cell');
    const intermediateCells = document.getElementById('interFilterGT').getElementsByClassName('cell');
    const resultCells = document.getElementById('transformedFilterMatrix').getElementsByClassName('cell');
    
    // Reset all highlights
    Array.from(filterCells).forEach(cell => cell.classList.remove('active'));
    Array.from(gCells).forEach(cell => cell.classList.remove('active'));
    Array.from(gtCells).forEach(cell => cell.classList.remove('active'));
    Array.from(intermediateCells).forEach(cell => cell.classList.remove('active'));
    Array.from(resultCells).forEach(cell => cell.classList.remove('active'));
    
    const filterGT = matrixMultiply(filter, GT);
    const transformedFilter = matrixMultiply(G, filterGT);
    
    let animPhase = 0; // 0: filter*GT, 1: G*(filter*GT)
    let currentRow = 0;
    let currentCol = 0;
    
    transformationAnimationStep = 0;
    document.getElementById('transformationStatus').textContent = 'Animating filter*Gᵀ calculation...';
    
    clearInterval(transformationInterval);
    transformationInterval = setInterval(() => {
        if (!transformationActive) return;

        // Reset highlights with safety checks
        Array.from(filterCells).forEach(cell => cell?.classList?.remove('active'));
        Array.from(gCells).forEach(cell => cell?.classList?.remove('active'));
        Array.from(gtCells).forEach(cell => cell?.classList?.remove('active'));
        Array.from(intermediateCells).forEach(cell => cell?.classList?.remove('active'));
        Array.from(resultCells).forEach(cell => cell?.classList?.remove('active'));

        if (animPhase === 0) {
            // Only highlight valid cells for 3x3 filter and 4x3 G matrix
            if (currentRow < 3 && currentCol < 4) {
                for (let k = 0; k < 3; k++) {
                    const filterIdx = currentRow * 3 + k;
                    const gtIdx = k * 4 + currentCol;
                    if (filterCells[filterIdx]) filterCells[filterIdx].classList.add('active');
                    if (gtCells[gtIdx]) gtCells[gtIdx].classList.add('active');
                }
                const intermediateIdx = currentRow * 4 + currentCol;
                if (intermediateCells[intermediateIdx]) intermediateCells[intermediateIdx].classList.add('active');
            }
            
            currentCol++;
            if (currentCol >= 4) {
                currentCol = 0;
                currentRow++;
                if (currentRow >= 3) {
                    animPhase = 1;
                    currentRow = 0;
                    currentCol = 0;
                    document.getElementById('transformationStatus').textContent = 'Animating G*(filter*Gᵀ) calculation...';
                }
            }
        } else {
            // Handle G matrix multiplication phase
            if (currentRow < 4 && currentCol < 4) {
                for (let k = 0; k < 3; k++) {
                    const gIdx = currentRow * 3 + k;
                    const intermediateIdx = k * 4 + currentCol;
                    if (gCells[gIdx]) gCells[gIdx].classList.add('active');
                    if (intermediateCells[intermediateIdx]) intermediateCells[intermediateIdx].classList.add('active');
                }
                const resultIdx = currentRow * 4 + currentCol;
                if (resultCells[resultIdx]) resultCells[resultIdx].classList.add('active');
            }
            
            currentCol++;
            if (currentCol >= 4) {
                currentCol = 0;
                currentRow++;
                if (currentRow >= 4) {
                    clearInterval(transformationInterval);
                    transformationActive = false;
                    document.getElementById('transformationStatus').textContent = 'Filter transformation complete!';
                    document.getElementById('animateBtn').textContent = 'Animate Again';
                    
                    // Show all results
                    fillMatrix(filterGT, 'interFilterGT', 'transform');
                    fillMatrix(transformedFilter, 'transformedFilterMatrix', 'filter');
                }
            }
        }
        
        transformationAnimationStep++;
    }, 500);
}

// Animate element-wise multiplication
function animateElementwiseMultiplication() {
    const inputCells = document.getElementById('transformedInputMatrix2').getElementsByClassName('cell');
    const filterCells = document.getElementById('transformedFilterMatrix2').getElementsByClassName('cell');
    const resultCells = document.getElementById('elementwiseProductMatrix').getElementsByClassName('cell');
    
    // Reset all highlights
    Array.from(inputCells).forEach(cell => cell.classList.remove('active'));
    Array.from(filterCells).forEach(cell => cell.classList.remove('active'));
    Array.from(resultCells).forEach(cell => cell.classList.remove('active'));
    
    let currentRow = 0;
    let currentCol = 0;
    
    transformationAnimationStep = 0;
    document.getElementById('transformationStatus').textContent = 'Animating element-wise multiplication...';
    
    clearInterval(transformationInterval);
    transformationInterval = setInterval(() => {
        if (!transformationActive) return;
        
        // Reset previous highlights
        Array.from(inputCells).forEach(cell => cell.classList.remove('active'));
        Array.from(filterCells).forEach(cell => cell.classList.remove('active'));
        Array.from(resultCells).forEach(cell => cell.classList.remove('active'));
        
        // Highlight current cells
        const idx = currentRow * 4 + currentCol;
        inputCells[idx].classList.add('active');
        filterCells[idx].classList.add('active');
        resultCells[idx].classList.add('active');
        
        currentCol++;
        if (currentCol >= 4) {
            currentCol = 0;
            currentRow++;
            if (currentRow >= 4) {
                clearInterval(transformationInterval);
                transformationActive = false;
                document.getElementById('transformationStatus').textContent = 'Element-wise multiplication complete!';
                document.getElementById('animateBtn').textContent = 'Animate Again';
            }
        }
        
        transformationAnimationStep++;
    }, 300);
}

// Animate inverse transformation
function animateInverseTransformation() {
    const AT = transpose(A);
    const productCells = document.getElementById('elementwiseProductMatrix2').getElementsByClassName('cell');
    const aCells = document.getElementById('aMatrix2').getElementsByClassName('cell');
    const atCells = document.getElementById('aMatrixT').getElementsByClassName('cell');
    const intermediateCells = document.getElementById('interAProduct').getElementsByClassName('cell');
    const resultCells = document.getElementById('outputMatrix2').getElementsByClassName('cell');
    
    // Reset all highlights
    Array.from(productCells).forEach(cell => cell.classList.remove('active'));
    Array.from(aCells).forEach(cell => cell.classList.remove('active'));
    Array.from(atCells).forEach(cell => cell.classList.remove('active'));
    Array.from(intermediateCells).forEach(cell => cell.classList.remove('active'));
    Array.from(resultCells).forEach(cell => cell.classList.remove('active'));
    
    const MAT = matrixMultiply(elementwiseProduct, AT);
    const finalOutput = matrixMultiply(A, MAT);
    
    let animPhase = 0; // 0: M*AT, 1: A*(M*AT)
    let currentRow = 0;
    let currentCol = 0;
    
    transformationAnimationStep = 0;
    document.getElementById('transformationStatus').textContent = 'Animating M×A⁻ᵀ calculation...';
    
    clearInterval(transformationInterval);
    transformationInterval = setInterval(() => {
        if (!transformationActive) return;
        
        // Reset previous highlights
        Array.from(productCells).forEach(cell => cell.classList.remove('active'));
        Array.from(aCells).forEach(cell => cell.classList.remove('active'));
        Array.from(atCells).forEach(cell => cell.classList.remove('active'));
        Array.from(intermediateCells).forEach(cell => cell.classList.remove('active'));
        Array.from(resultCells).forEach(cell => cell.classList.remove('active'));
        
        if (animPhase === 0) { // M*AT calculation
            // For M×AT, we need to highlight the current row of M
            // and the current column of AT
            for (let k = 0; k < 4; k++) {
                // Highlight current M row
                productCells[currentRow * 4 + k].classList.add('active');
                
                // Highlight current AT column - AT is 4x2
                if (k < 4) {
                    const atCellIndex = k * 2 + currentCol;
                    if (atCells[atCellIndex]) atCells[atCellIndex].classList.add('active');
                }
            }
            
            // Highlight result cell in M×AT
            if (intermediateCells[currentRow * 2 + currentCol]) {
                intermediateCells[currentRow * 2 + currentCol].classList.add('active');
            }
            
            currentCol++;
            if (currentCol >= 2) { // AT has 2 columns
                currentCol = 0;
                currentRow++;
                if (currentRow >= 4) { // M has 4 rows
                    animPhase = 1;
                    currentRow = 0;
                    currentCol = 0;
                    document.getElementById('transformationStatus').textContent = 'Animating A×(M×A⁻ᵀ) calculation...';
                }
            }
        } else { // A*(M*AT) calculation
            // For A×(M×AT), we need to highlight the current row of A
            // and the current column of (M×AT)
            for (let k = 0; k < 4; k++) {
                // Highlight current A row (if k is in range)
                if (k < 4 && currentRow * 4 + k < aCells.length) {
                    aCells[currentRow * 4 + k].classList.add('active');
                }
            }
            
            // Highlight current (M×AT) column
            for (let k = 0; k < 4; k++) {
                if (k < 4 && k * 2 + currentCol < intermediateCells.length) {
                    intermediateCells[k * 2 + currentCol].classList.add('active');
                }
            }
            
            // Highlight result cell
            if (resultCells[currentRow * 2 + currentCol]) {
                resultCells[currentRow * 2 + currentCol].classList.add('active');
            }
            
            currentCol++;
            if (currentCol >= 2) { // MAT has 2 columns
                currentCol = 0;
                currentRow++;
                if (currentRow >= 2) { // A has 2 rows
                    clearInterval(transformationInterval);
                    transformationActive = false;
                    document.getElementById('transformationStatus').textContent = 'Inverse transformation complete!';
                    document.getElementById('animateBtn').textContent = 'Animate Again';
                    
                    // Show all results
                    fillMatrix(MAT, 'interAProduct', 'transform');
                    fillMatrix(finalOutput, 'outputMatrix', 'output');
                    fillMatrix(finalOutput, 'outputMatrix2', 'output');
                }
            }
        }
        
        transformationAnimationStep++;
    }, 500);
}

// Start convolution animation
function startConvolutionAnimation() {
    const kernelHighlight = document.getElementById('kernelHighlight');
    const animOutputMatrix = document.getElementById('animOutputMatrix');
    const outputCells = animOutputMatrix.getElementsByClassName('cell');

    // Reset output matrix
    for (let i = 0; i < 2; i++) {
        for (let j = 0; j < 2; j++) {
            outputCells[i * 2 + j].textContent = '0';
            outputCells[i * 2 + j].classList.remove('active');
        }
    }

    // Set up kernel highlight
    const cellSize = 35; // match the CSS size
    kernelHighlight.style.width = `${3 * cellSize + 6}px`;
    kernelHighlight.style.height = `${3 * cellSize + 6}px`;

    let position = 0;
    clearInterval(animationInterval);

    animationInterval = setInterval(() => {
        // Position is 0, 1, 2, 3 for the 4 possible positions of the kernel
        const row = Math.floor(position / 2);
        const col = position % 2;

        // Position the highlight
        kernelHighlight.style.left = `${col * cellSize}px`;
        kernelHighlight.style.top = `${row * cellSize}px`;

        // Calculate convolution result for this position
        let sum = 0;
        for (let i = 0; i < 3; i++) {
            for (let j = 0; j < 3; j++) {
                sum += input[row + i][col + j] * filter[i][j];
            }
        }

        // Update output
        outputCells[row * 2 + col].textContent = sum;
        outputCells[row * 2 + col].classList.add('active');

        // Move to next position or reset
        position++;
        if (position >= 4) {
            clearInterval(animationInterval);
            document.getElementById('transformationStatus').textContent = 'Convolution complete!';
        }
    }, 1000);
}

// Initialize when the page loads
document.addEventListener('DOMContentLoaded', function() {
    setupMatrices();
    updateExplanation();
    
    // Add event listeners to buttons
    document.getElementById('prevBtn').addEventListener('click', prevStep);
    document.getElementById('nextBtn').addEventListener('click', nextStep);
    document.getElementById('resetBtn').addEventListener('click', reset);
    document.getElementById('animateBtn').addEventListener('click', startTransformationAnimation);
    document.getElementById('randomizeBtn').addEventListener('click', function() {
        // Generate new input data
        input = Array.from({length:4}, () => 
            Array.from({length:4}, () => Math.floor(Math.random() * 5))
        );
        
        // Generate new filter data
        filter = Array.from({length:3}, () => 
            Array.from({length:3}, () => Math.floor(Math.random() * 3))
        );
        
        // Update all input and filter matrices
        fillMatrix(input, 'inputMatrix', 'input');
        fillMatrix(input, 'inputMatrix2', 'input');
        fillMatrix(input, 'animInputMatrix', 'input');
        
        fillMatrix(filter, 'filterMatrix', 'filter');
        fillMatrix(filter, 'filterMatrix2', 'filter');
        
        // Reset output matrices
        output = [[0,0],[0,0]];
        fillMatrix(output, 'outputMatrix', 'output');
        fillMatrix(output, 'outputMatrix2', 'output');
        fillMatrix(output, 'animOutputMatrix', 'output');
        
        // Clear any transformation results
        transformedInput = [];
        transformedFilter = [];
        elementwiseProduct = [];
    });
    
    // Add event listeners to step buttons
    document.querySelectorAll('.step-btn').forEach(btn => {
        btn.addEventListener('click', function() {
            // Get the step number from data attribute
            const stepNum = parseInt(this.getAttribute('data-step'));
            
            // Set the current step and update display
            if (stepNum !== currentStep) {
                currentStep = stepNum;
                updateStepDisplay();
            }
        });
    });
});