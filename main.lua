local config = require("config")
local Button = require("Button")
local json = require("json")

local colors = config.colors
local screen = config.screen
local shapes = config.shapes

local activeShape
local grid
local cellSize = screen.cellSize
local gridWidth = screen.middlePanelWidth
local gridHeight = screen.panelHeight

local leftPanelWidth = screen.leftPanelWidth * cellSize
local middlePanelWidth = screen.middlePanelWidth * cellSize
local rightPanelWidth = screen.rightPanelWidth * cellSize
local panelHeight = screen.panelHeight * cellSize

local windowWidth = leftPanelWidth + middlePanelWidth + rightPanelWidth
local windowHeight = panelHeight

local score = 0
local timeElapsed = 0
local dropInterval = 1
local moveCooldown = 0.1
local moveTimeElapsed = 0

local nextShapes = {}

local moveLeft = false
local moveRight = false
local fastDrop = false
local isPaused = false
local isGameOver = false
local isSaveWindowVisible = false

local saveFileName = ""
local saveButton

local gameOverButtons = {}

local rowsToAnimate = {}
local animationTimer = 0
local animationDurationPerBlock = 0.005
local animationProgress = 0

local isLoadWindowVisible = false
local currentSaveFiles = {}
local currentSaveFileIndex = 1
local savesPerPage = 5
local nextButton
local backButton

function love.load()
    love.window.setTitle(screen.gameTitle)
    love.window.setMode(windowWidth, windowHeight)

    font = love.graphics.newFont(screen.fontSize)

    pauseButtons = {
        Button:new(leftPanelWidth + middlePanelWidth / 2 - 150, 225, 300, 30, "Resume", togglePause, { font = font, defaultColor = colors.Black, hoverColor = colors.Pink, textColor = colors.White }),
        Button:new(leftPanelWidth + middlePanelWidth / 2 - 150, 275, 300, 30, "New Game", newGame, { font = font, defaultColor = colors.Black, hoverColor = colors.Pink, textColor = colors.White }),
        Button:new(leftPanelWidth + middlePanelWidth / 2 - 150, 325, 300, 30, "Save", saveGame, { font = font, defaultColor = colors.Black, hoverColor = colors.Pink, textColor = colors.White }),
        Button:new(leftPanelWidth + middlePanelWidth / 2 - 150, 375, 300, 30, "Load Save", toggleLoadWindow, { font = font, defaultColor = colors.Black, hoverColor = colors.Pink, textColor = colors.White }),
        Button:new(leftPanelWidth + middlePanelWidth / 2 - 150, 425, 300, 30, "Exit", function() love.event.quit() end, { font = font, defaultColor = colors.Black, hoverColor = colors.Pink, textColor = colors.White })
    }

    gameOverButtons = {
        Button:new(windowWidth / 2 - 100, windowHeight / 2, 200, 50, "New Game", newGame, { font = font, defaultColor = colors.Black, hoverColor = colors.Pink, textColor = colors.White }),
        Button:new(windowWidth / 2 - 100, windowHeight / 2 + 60, 200, 50, "Exit", function() love.event.quit() end, { font = font, defaultColor = colors.Black, hoverColor = colors.Pink, textColor = colors.White })
    }

    resetGame()
end

function initNextShapes(num)
    for i = 1, num do
        table.insert(nextShapes, randomShape())
    end
end

function randomShape()
    local shapeKeys = {"I", "J", "L", "O", "S", "T", "Z"}
    local chosenRandomShape = shapeKeys[math.random(#shapeKeys)]
    return {
        type = chosenRandomShape,
        shape = shapes[chosenRandomShape],
        rotation = 1,
        color = config.shapeColors[chosenRandomShape]
    }
end

function generateNewShape()
    activeShape = table.remove(nextShapes, 1)
    activeShape.x = math.floor(gridWidth / 2)
    activeShape.y = 1
    table.insert(nextShapes, randomShape())

    if not doesShapeFit(activeShape.x, activeShape.y, activeShape.shape[activeShape.rotation]) then
        isGameOver = true
    end
end

function resetGame()
    if isPaused then
        isPaused = not isPaused
    end
    grid = {}
    for i = 1, gridHeight do
        grid[i] = {}
        for j = 1, gridWidth do
            grid[i][j] = { occupied = false, color = nil }
        end
    end
    score = 0
    timeElapsed = 0
    moveTimeElapsed = 0
    isGameOver = false
    nextShapes = {}
    rowsToAnimate = {}
    animationTimer = 0
    animationProgress = 0
    initNextShapes(3)
    generateNewShape()
end

function newGame()
    resetGame()
end

function love.update(dt)
    if isSaveWindowVisible then
        local mouseX, mouseY = love.mouse.getPosition()
        saveButton:update(mouseX, mouseY)
    elseif isLoadWindowVisible then
        local mouseX, mouseY = love.mouse.getPosition()
        if backButton then backButton:update(mouseX, mouseY) end
        if nextButton then nextButton:update(mouseX, mouseY) end
    elseif isPaused or isGameOver then
        local mouseX, mouseY = love.mouse.getPosition()
        if isGameOver then
            for _, button in ipairs(gameOverButtons) do
                button:update(mouseX, mouseY)
            end
        else
            for _, button in ipairs(pauseButtons) do
                button:update(mouseX, mouseY)
            end
        end
    else
        if #rowsToAnimate > 0 then
            animationTimer = animationTimer + dt
            if animationTimer >= animationDurationPerBlock then
                animationProgress = animationProgress + 1
                animationTimer = 0
                if animationProgress > gridWidth then
                    removeAnimatedRows()
                    rowsToAnimate = {}
                    animationProgress = 0
                end
            end
        else
            timeElapsed = timeElapsed + dt
            moveTimeElapsed = moveTimeElapsed + dt
            -- Gameplay logic
            if moveLeft and moveTimeElapsed >= moveCooldown then
                moveShapeHorizontally(-1)
                moveTimeElapsed = 0
            end
            if moveRight and moveTimeElapsed >= moveCooldown then
                moveShapeHorizontally(1)
                moveTimeElapsed = 0
            end
            if fastDrop then
                dropInterval = 0.05
            else
                dropInterval = 1
            end
            if timeElapsed >= dropInterval then
                moveShapeDown()
                timeElapsed = 0
            end
        end
    end
end

function love.draw()
    if isSaveWindowVisible then
        drawSaveWindow()
    elseif isLoadWindowVisible then
        drawLoadWindow()
    elseif isGameOver then
        drawGameOverMenu()
    elseif isPaused then
        drawPauseMenu()
    else
        drawMainGUI()
    end
end

function drawMainGUI()
    drawLeftPanel()
    drawMiddlePanel()
    drawRightPanel()
end

-- LEFT PANEL
function drawLeftPanel()
    love.graphics.setColor(colors.Pink)
    love.graphics.rectangle("fill", 0, 0, leftPanelWidth, windowHeight)

    love.graphics.setColor(colors.Black)
    love.graphics.setFont(font)
    love.graphics.print("SCORE:", 50, 50)

    love.graphics.setColor(colors.White)
    love.graphics.rectangle("line", 20, 100, 160, 50)
    love.graphics.setColor(colors.White)
    love.graphics.rectangle("fill", 20, 100, 160, 50)

    love.graphics.setColor(colors.Black)
    love.graphics.printf(tostring(score), 20, 115, 160, "center")
end

-- MIDDLE PANEL
function drawMiddlePanel()
    love.graphics.setColor(colors.White)
    love.graphics.rectangle("fill", leftPanelWidth, 0, middlePanelWidth, windowHeight)

    drawGrid()
    drawShape(activeShape)
end

-- RIGHT PANEL
function drawRightPanel()
    love.graphics.setColor(colors.Purple)
    love.graphics.rectangle("fill", leftPanelWidth + middlePanelWidth, 0, rightPanelWidth, windowHeight)

    love.graphics.setColor(colors.Black)
    love.graphics.setFont(font)
    love.graphics.print("NEXT:", leftPanelWidth + middlePanelWidth + 50, 50)

    drawNextShapes()
end

function drawGrid()
    for i = 1, gridHeight do
        for j = 1, gridWidth do
            if grid[i][j].occupied then
                local color = grid[i][j].color

                if contains(rowsToAnimate, i) then
                    if j <= animationProgress then
                        love.graphics.setColor(1, 1, 1)
                    else
                        love.graphics.setColor(color)
                    end
                else
                    love.graphics.setColor(color)
                end

                love.graphics.rectangle("fill", (j - 1) * cellSize + leftPanelWidth, (i - 1) * cellSize, cellSize, cellSize)
            else
                love.graphics.setColor(0.1, 0.1, 0.1)
                love.graphics.rectangle("line", (j - 1) * cellSize + leftPanelWidth, (i - 1) * cellSize, cellSize, cellSize)
            end
        end
    end
end

function drawShape(shape)
    love.graphics.setColor(shape.color)
    for _, block in ipairs(shape.shape[shape.rotation]) do
        local x = (shape.x + block[1] - 1) * cellSize + leftPanelWidth
        local y = (shape.y + block[2] - 1) * cellSize
        love.graphics.rectangle("fill", x, y, cellSize, cellSize)
    end
end

function drawNextShapes()
    for i, shapeInfo in ipairs(nextShapes) do
        local startX = leftPanelWidth + middlePanelWidth + 50
        local startY = 100 + (i - 1) * 150

        love.graphics.setColor(colors.White)
        love.graphics.rectangle("line", startX, startY, 120, 120)

        love.graphics.setColor(shapeInfo.color)
        local shape = shapeInfo.shape[shapeInfo.rotation]

        local minX, minY = shape[1][1], shape[1][2]
        local maxX, maxY = shape[1][1], shape[1][2]
        for j = 2, #shape do
            if shape[j][1] < minX then minX = shape[j][1] end
            if shape[j][2] < minY then minY = shape[j][2] end
            if shape[j][1] > maxX then maxX = shape[j][1] end
            if shape[j][2] > maxY then maxY = shape[j][2] end
        end
        local offsetX = (120 - (maxX - minX + 1) * cellSize) / 2
        local offsetY = (120 - (maxY - minY + 1) * cellSize) / 2

        for _, block in ipairs(shape) do
            local x = startX + (block[1] - minX) * cellSize + offsetX
            local y = startY + (block[2] - minY) * cellSize + offsetY
            love.graphics.rectangle("fill", x, y, cellSize, cellSize)
        end
    end
end

function moveShapeHorizontally(dx)
    local newX = activeShape.x + dx
    if doesShapeFit(newX, activeShape.y, activeShape.shape[activeShape.rotation]) then
        activeShape.x = newX
    end
end

function moveShapeDown()
    local newY = activeShape.y + 1
    if doesShapeFit(activeShape.x, newY, activeShape.shape[activeShape.rotation]) then
        activeShape.y = newY
    else
        placeShape()
        generateNewShape()
    end
end

function rotateCurrentShape()
    local newRotation = (activeShape.rotation % #activeShape.shape) + 1
    local newShape = activeShape.shape[newRotation]

    if doesShapeFit(activeShape.x, activeShape.y, newShape) then
        activeShape.rotation = newRotation
    else
        if doesShapeFit(activeShape.x - 1, activeShape.y, newShape) then
            activeShape.x = activeShape.x - 1
            activeShape.rotation = newRotation
        elseif doesShapeFit(activeShape.x + 1, activeShape.y, newShape) then
            activeShape.x = activeShape.x + 1
            activeShape.rotation = newRotation
        elseif doesShapeFit(activeShape.x - 2, activeShape.y, newShape) then
            activeShape.x = activeShape.x - 2
            activeShape.rotation = newRotation
        elseif doesShapeFit(activeShape.x + 2, activeShape.y, newShape) then
            activeShape.x = activeShape.x + 2
            activeShape.rotation = newRotation
        end
    end
end

function doesShapeFit(x, y, shape)
    for _, block in ipairs(shape) do
        local newX = x + block[1]
        local newY = y + block[2]

        if newX < 1 or newX > gridWidth or newY > gridHeight or (newY > 0 and grid[newY][newX].occupied) then
            return false
        end
    end
    return true
end

function placeShape()
    for _, block in ipairs(activeShape.shape[activeShape.rotation]) do
        local x = activeShape.x + block[1]
        local y = activeShape.y + block[2]

        if y > 0 then
            grid[y][x].occupied = true
            grid[y][x].color = activeShape.color
        end
    end
    checkFullRows()
end

function checkFullRows()
    local fullRows = {}
    for row = 1, gridHeight do
        local isFull = true
        for col = 1, gridWidth do
            if not grid[row][col].occupied then
                isFull = false
                break
            end
        end
        if isFull then
            table.insert(fullRows, row)
        end
    end

    if #fullRows > 0 then
        rowsToAnimate = fullRows
        animationTimer = 0
        animationProgress = 0
    end
end

function removeAnimatedRows()
    table.sort(rowsToAnimate, function(a, b) return a < b end)

    local rowsRemoved = #rowsToAnimate
    print("Removing rows:", table.concat(rowsToAnimate, ", "))

    for _, row in ipairs(rowsToAnimate) do
        for r = row, 2, -1 do
            for col = 1, gridWidth do
                grid[r][col] = grid[r - 1][col]
            end
        end
        for col = 1, gridWidth do
            grid[1][col] = { occupied = false, color = nil }
        end
    end

    updateScore(rowsRemoved)

    rowsToAnimate = {}
    animationTimer = 0
    animationProgress = 0
end

function updateScore(rows)
    local scores = {0, 40, 100, 300, 1200}
    score = score + scores[rows + 1]
end

function togglePause()
    isPaused = not isPaused
end

function love.keypressed(key)
    if isSaveWindowVisible then
        if key == "backspace" then
            saveFileName = saveFileName:sub(1, -2)
        end
    elseif isLoadWindowVisible then
        -- pass
    else
        if key == 'escape' then
            togglePause()
        elseif key == 'left' then
            moveLeft = true
        elseif key == 'right' then
            moveRight = true
        elseif key == 'up' then
            rotateCurrentShape()
        elseif key == 'down' then
            fastDrop = true
        end
    end
end

function love.textinput(t)
    if isSaveWindowVisible then
        saveFileName = saveFileName .. t
    end
end

function love.keyreleased(key)
    if key == 'down' then
        fastDrop = false
    elseif key == 'left' then
        moveLeft = false
    elseif key == 'right' then
        moveRight = false
    end
end

local function sanitizeFilename(filename)
    return (filename:gsub("%.json$", ""))
end

function loadGameFromFile(filename)
    filename = sanitizeFilename(filename)
    local saveDir = "saves"
    local fullPath = saveDir .. "/" .. filename .. ".json"
    print("Loading from: " .. fullPath)

    -- Check if fullPath is empty
    if fullPath == nil or fullPath == "" then
        print("Error: File path is empty.")
        return
    end

    local fileContent, size = love.filesystem.read(fullPath)
    if fileContent then
        local saveData = json.decode(fileContent)
        if saveData then
            grid = saveData.grid
            activeShape = saveData.activeShape
            nextShapes = saveData.nextShapes
            score = saveData.score
            timeElapsed = saveData.timeElapsed
            print("Game loaded successfully from " .. fullPath)
        else
            print("Failed to decode save data from " .. fullPath)
        end
    else
        print("Failed to load game from " .. fullPath)
    end
end

function love.mousepressed(x, y, button)
    if button == 1 then
        if isSaveWindowVisible then
            saveButton:click()
        elseif isLoadWindowVisible then
            if backButton then backButton:click() end
            if nextButton then nextButton:click() end

            local startIndex = currentSaveFileIndex
            local endIndex = math.min(currentSaveFileIndex + savesPerPage - 1, #currentSaveFiles)

            for i = startIndex, endIndex do
                local file = currentSaveFiles[i]
                local fileName = file.name:match("([^/]+)$")
                local yPosition = (love.graphics.getHeight() - 300) / 2 + 60 + (i - startIndex) * 40

                print(string.format("Checking file: %s at position: %d (mouse: %d, %d)", fileName, yPosition, x, y))

                if x > (love.graphics.getWidth() - 400) / 2 + 20 and x < (love.graphics.getWidth() - 400) / 2 + 380 and y > yPosition and y < yPosition + 30 then
                    print("Loading file:", fileName)  -- Debug print
                    loadGameFromFile(fileName)
                    isLoadWindowVisible = false
                    isPaused = false
                    return
                end
            end
        elseif isGameOver then
            for _, btn in ipairs(gameOverButtons) do
                if btn:isFocused(x, y) then
                    btn:click()
                end
            end
        elseif isPaused then
            for _, btn in ipairs(pauseButtons) do
                if btn:isFocused(x, y) then
                    btn:click()
                end
            end
        end
    end
end

function drawPauseMenu()
    love.graphics.setColor(0, 0, 0, 0.5)
    love.graphics.rectangle("fill", 0, 0, windowWidth, windowHeight)

    love.graphics.setColor(1, 1, 1)
    love.graphics.rectangle("fill", leftPanelWidth + middlePanelWidth / 2 - 150, windowHeight / 2 - 150, 300, 400)

    love.graphics.setColor(0, 0, 0)
    love.graphics.setFont(font)
    love.graphics.printf("PAUSE", leftPanelWidth + middlePanelWidth / 2 - 150, windowHeight / 2 - 130, 300, "center")

    for _, button in ipairs(pauseButtons) do
        button:draw()
    end
end

function drawGameOverMenu()
    love.graphics.setColor(0, 0, 0, 0.5)
    love.graphics.rectangle("fill", 0, 0, windowWidth, windowHeight)

    love.graphics.setColor(1, 1, 1)
    love.graphics.rectangle("fill", windowWidth / 2 - 150, windowHeight / 2 - 150, 300, 300)

    love.graphics.setColor(0, 0, 0)
    love.graphics.setFont(font)
    love.graphics.printf("GAME OVER", windowWidth / 2 - 150, windowHeight / 2 - 130, 300, "center")
    love.graphics.printf("SCORE: " .. tostring(score), windowWidth / 2 - 150, windowHeight / 2 - 70, 300, "center")

    for _, button in ipairs(gameOverButtons) do
        button:draw()
    end
end

function contains(table, element)
    for _, value in ipairs(table) do
        if value == element then
            return true
        end
    end
    return false
end

function saveGame()
    showSaveWindow()
end

function showSaveWindow()
    isSaveWindowVisible = true
    saveFileName = ""
    saveButton = Button:new(
        (love.graphics.getWidth() - 100) / 2,
        (love.graphics.getHeight() + 60) / 2,
        100,
        40,
        "OK",
        function()
            if saveFileName ~= "" then
                saveGameToFile(saveFileName)
                isSaveWindowVisible = false
                isPaused = true
            else
                print("Save file name is empty")
            end
        end,
        { font = font, defaultColor = colors.Black, hoverColor = colors.Pink, textColor = colors.White }
    )
end

function saveGameToFile(filename)
    local saveData = {
        grid = grid,
        activeShape = activeShape,
        nextShapes = nextShapes,
        score = score,
        timeElapsed = timeElapsed,
        date = os.date("%Y-%m-%d %H:%M:%S")
    }

    local saveDir = "saves"
    if not love.filesystem.getInfo(saveDir) then
        love.filesystem.createDirectory(saveDir)
    end

    local fullPath = saveDir .. "/" .. filename .. ".json"
    print("Saving to: " .. fullPath)

    local encodedData = json.encode(saveData)
    if love.filesystem.write(fullPath, encodedData) then
        print("Game saved successfully to " .. fullPath)
    else
        print("Failed to save game")
    end
end

function drawSaveWindow()
    local windowWidth = 400
    local windowHeight = 200
    local windowX = (love.graphics.getWidth() - windowWidth) / 2
    local windowY = (love.graphics.getHeight() - windowHeight) / 2

    love.graphics.setColor(1, 1, 1)
    love.graphics.rectangle("fill", windowX, windowY, windowWidth, windowHeight)

    love.graphics.setColor(0, 0, 0)
    love.graphics.setFont(font)
    love.graphics.printf("Enter save file name:", windowX, windowY + 20, windowWidth, "center")

    love.graphics.setColor(0.9, 0.9, 0.9)
    love.graphics.rectangle("fill", windowX + 50, windowY + 80, 300, 40)
    love.graphics.setColor(0, 0, 0)
    love.graphics.printf(saveFileName, windowX + 55, windowY + 90, 290)

    saveButton:draw()
end

local function getSaveFiles()
    local saveDir = "saves"
    local files = love.filesystem.getDirectoryItems(saveDir)
    local saveFiles = {}

    for _, file in ipairs(files) do
        if file:match("%.json$") then
            local info = love.filesystem.getInfo(saveDir .. "/" .. file)
            table.insert(saveFiles, { name = file, modtime = info.modtime })
        end
    end

    table.sort(saveFiles, function(a, b) return a.modtime > b.modtime end)
    return saveFiles
end

function toggleLoadWindow()
    isLoadWindowVisible = not isLoadWindowVisible
    if isLoadWindowVisible then
        currentSaveFiles = getSaveFiles()
        currentSaveFileIndex = 1

        backButton = Button:new(
            (love.graphics.getWidth() - 100) / 2 - 150,
            (love.graphics.getHeight() + 200) / 2,
            100,
            40,
            "Back",
            function()
                if currentSaveFileIndex > 1 then
                    currentSaveFileIndex = currentSaveFileIndex - savesPerPage
                end
            end,
            { font = font, defaultColor = colors.Black, hoverColor = colors.Pink, textColor = colors.White }
        )

        nextButton = Button:new(
            (love.graphics.getWidth() - 100) / 2 + 150,
            (love.graphics.getHeight() + 200) / 2,
            100,
            40,
            "Next",
            function()
                if currentSaveFileIndex + savesPerPage - 1 < #currentSaveFiles then
                    currentSaveFileIndex = currentSaveFileIndex + savesPerPage
                end
            end,
            { font = font, defaultColor = colors.Black, hoverColor = colors.Pink, textColor = colors.White }
        )
    end
end

function drawLoadWindow()
    local windowWidth = 400
    local windowHeight = 300
    local windowX = (love.graphics.getWidth() - windowWidth) / 2
    local windowY = (love.graphics.getHeight() - windowHeight) / 2

    love.graphics.setColor(1, 1, 1)
    love.graphics.rectangle("fill", windowX, windowY, windowWidth, windowHeight)

    love.graphics.setColor(0, 0, 0)
    love.graphics.setFont(font)
    love.graphics.printf("Select a save file:", windowX, windowY + 20, windowWidth, "center")

    local startIndex = currentSaveFileIndex
    local endIndex = math.min(currentSaveFileIndex + savesPerPage - 1, #currentSaveFiles)

    for i = startIndex, endIndex do
        local file = currentSaveFiles[i]
        local y = windowY + 60 + (i - startIndex) * 40
        local fileName = file.name:match("([^/]+)$")
        love.graphics.printf(fileName, windowX + 20, y, windowWidth - 40, "left")
    end

    if currentSaveFileIndex > 1 then
        backButton:draw()
    end
    if endIndex < #currentSaveFiles then
        nextButton:draw()
    end
end

function loadGame()
    toggleLoadWindow()
end
