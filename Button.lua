local Button = {}
Button.__index = Button

function Button:new(x, y, width, height, label, onClick, options)
    local self = setmetatable({}, Button)
    self.x = x
    self.y = y
    self.width = width
    self.height = height
    self.label = label
    self.onClick = onClick
    self.isHovered = false
    self.font = options.font or love.graphics.newFont(20)
    self.defaultColor = options.defaultColor or {1, 1, 1}
    self.hoverColor = options.hoverColor or {1, 0.75, 0.8}
    self.textColor = options.textColor or {0, 0, 0}
    return self
end

function Button:draw()
    if self.isHovered then
        love.graphics.setColor(self.hoverColor)
    else
        love.graphics.setColor(self.defaultColor)
    end
    love.graphics.rectangle("fill", self.x, self.y, self.width, self.height)
    love.graphics.setColor(self.textColor)
    love.graphics.setFont(self.font)
    love.graphics.printf(self.label, self.x, self.y + (self.height - self.font:getHeight()) / 2, self.width, "center")
end

function Button:isFocused(x, y)
    return x > self.x and x < self.x + self.width and y > self.y and y < self.y + self.height
end

function Button:click()
    self.onClick()
end

function Button:update(mouseX, mouseY)
    self.isHovered = self:isFocused(mouseX, mouseY)
end

return Button
