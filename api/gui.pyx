import pygame

class Gui:
    def __init__(self):
        self.screen = pygame.display.get_surface()
        self.buttons = []
        self.textboxes = []
        self.bars = []
        self.valSliders = []
        self.itemSlots = []
        self.extraItems = []
        self.currentTextBox = None

    def drawBackgroundLayer(self):
        '''
        Draw the background layer of the GUI screen
        '''
        pass

    def drawMiddleLayer(self, mousePos):
        '''
        Draw the middleground layer of the GUI screen
        '''
        for slot in self.itemSlots:
            slot.draw(self.screen, mousePos)
        for item in self.extraItems:
            item.draw(self.screen, mousePos)
        for slider in self.valSliders:
            slider.draw(self.screen, mousePos)

    def drawForegroundLayer(self, mousePos):
        '''
        Draw the foreground layer of the GUI screen
        '''
        for button in self.buttons:
            button.draw(self.screen, mousePos)
        for box in self.textboxes:
            box.draw(self.screen, mousePos)
        for bar in self.bars:
            bar.draw(self.screen, mousePos)

    def addItem(self, item):
        '''
        Add an Item to be drawn
        '''
        if 'draw' not in dir(item):
            raise Exception('Invalid Item Being Added To Gui.')
        self.extraItems.append(item)

class Overlay(Gui):
    def doKeyPress(self, event):
        '''
        Handle a key press event
        '''
        pass

class ItemSlot:
    def __init__(self, item, pos, size):
        self.pos = [a+3 for a in pos]
        self.item = item
        self.item.img = pygame.transform.scale(self.item.img, [size-5, size-5])
        self.button = Button(pos+[size, size], '')

    def draw(self, screen, mousePos):
        self.button.draw(screen, [0, 0])
        imgRect = screen.blit(self.item.img, self.pos)
        if self.button.isHovered(mousePos):
            # Draw a semi transparent square over the itemslot
            square = pygame.Surface([self.button.rect[2]+1 for a in range(2)])
            square.set_alpha(128)
            square.fill((0, 0, 0))
            screen.blit(square, [a-3 for a in self.pos])

class Slider:
    def __init__(self, rect, colour):
        self.rect = rect
        self.value = 0
        self.displayValue = self.value
        self.bar = Bar(rect[:2], rect[2], rect[3], colour)

    def draw(self, screen, mousePos):
        if self.isHovered(mousePos) and pygame.mouse.get_pressed()[0]:
            self.value = abs(mousePos[0]-self.rect[0])/self.rect[2]
            # Draw a value label
            font = pygame.font.Font('resources/font/main.ttf', 15)
            text = font.render(str(self.displayValue), True, (0, 0, 0))
            pos = [mousePos[0]-text.get_rect().width//2, mousePos[1]-30]
            self.screen.blit(text, pos)

        self.bar.draw(screen, mousePos)

        # Draw the circle over the top of the bar
        circlePos = [int(self.rect[0]+self.rect[2]*self.value), int(self.rect[1]+self.rect[3]//2)]
        pygame.draw.circle(screen, (255, 255, 255), circlePos, self.rect[3])

        self.displayValue = round(self.value, 2)

    def isHovered(self, mousePos):
        x, y = mousePos
        if y > self.rect[1]-self.rect[3]//2 and y < self.rect[1]+int(self.rect[3]*1.5):
            if x > self.rect[0] and x < self.rect[0]+self.rect[2]:
                return True
        return False

class Bar:
    def __init__(self, topLeftPos, width, height, colour, percentage=100, label=''):
        self.pos = topLeftPos
        self.width = width
        self.height = height+height%2
        if width < height:
            raise Exception('Invalid Gui Bar Dimensions!')
        self.percentage = percentage
        self.colour = colour
        self.label = label

    def draw(self, screen, mousePos):
        lineLength = self.width-self.height

        # Get the left and right points of the bar's circles
        leftPos = [self.pos[0]+self.height//2, self.pos[1]+self.height//2]
        rightPos = [leftPos[0]+lineLength, leftPos[1]]
        # Get the end points of the line
        leftLinePos = [leftPos[0], leftPos[1]-1]
        rightLinePos = [rightPos[0], rightPos[1]-1]

        # Draw the grey underbar
        pygame.draw.line(screen, (192, 192, 192), leftLinePos, rightLinePos, self.height)
        pygame.draw.circle(screen, (192, 192, 192), leftPos, self.height//2)
        pygame.draw.circle(screen, (192, 192, 192), rightPos, self.height//2)

        # Draw the bar over the top
        # Get the scaled position of the end of the bar
        scaledRightPos = [leftPos[0] + round(lineLength * self.percentage/100), rightLinePos[1]]
        pygame.draw.line(screen, self.colour, leftLinePos, scaledRightPos, self.height)
        # Draw the end circles of the bar
        scaledRightPos = [scaledRightPos[0], scaledRightPos[1]+1]
        pygame.draw.circle(screen, self.colour, leftPos, self.height//2)
        pygame.draw.circle(screen, self.colour, scaledRightPos, self.height//2)

        # Draw the label
        if self.label:
            font = pygame.font.Font('resources/font/main.ttf', self.height-4)
            text = font.render(self.label, True, (255, 255, 255))
            pos = [self.pos[0]+8, self.pos[1]]
            screen.blit(text, pos)

class Button:
    def __init__(self, rect, label):
        self.rect = rect
        self.label = label
        self.font = pygame.font.Font('resources/font/main.ttf', 30)

    def draw(self, screen, mousePos):
        '''
        Draw the button to the given surface
        '''
        colour1 = (65, 55, 40)
        if self.isHovered(mousePos):
            colour2 = (138, 114, 84)
        else:
            colour2 = (173, 144, 106)

        # Draw the button
        pygame.draw.rect(screen, colour2, self.rect, 0)
        pygame.draw.rect(screen, colour1, self.rect, 4)

        # Draw the label on the button
        label = self.getLabelObject()
        screen.blit(label, self.getLabelPos(label))

    def getLabelObject(self):
        '''
        Return a cropped version of the label to fit into the button width
        '''
        label = self.label
        text = self.font.render(label, True, (0, 0, 0))
        while text.get_rect().width+10 > self.rect[2]:
            label = label[1:]
            text = self.font.render(label, True, (0, 0, 0))
        return text

    def getLabelPos(self, label):
        '''
        Return the position to blit the button's label to
        '''
        return [self.rect[0]+self.rect[2]//2-label.get_rect().width//2, self.rect[1]+self.rect[3]//2-20]

    def isHovered(self, mousePos):
        '''
        Return if the given mousePos is above this button
        '''
        x, y = mousePos
        if x > self.rect[0] and x < self.rect[0]+self.rect[2]:
            if y > self.rect[1] and y < self.rect[1]+self.rect[3]:
                return True
        return False

    def onClick(self, game):
        '''
        Handle a click event on this button
        '''
        pass

class TextBox(Button):
    def __init__(self, rect, label):
        super().__init__(rect, label)
        self.text = ''

    def getLabelObject(self):
        '''
        Return a cropped version of the label if no input text has been entered
        '''
        if not self.text:
            label = self.label
        else:
            label = ''
        text = self.font.render(label, True, (64, 64, 64))
        while text.get_rect().width+10 > self.rect[2]:
            label = label[1:]
            text = self.font.render(label, True, (64, 64, 64))
        return text

    def getTextObject(self):
        '''
        Return a cropped version of the current input text
        '''
        label = self.text
        text = self.font.render(label, True, (0, 0, 0))
        while text.get_rect().width+10 > self.rect[2]:
            label = label[1:]
            text = self.font.render(label, True, (0, 0, 0))
        return text

    def draw(self, screen, mousePos):
        '''
        Draw the button to the given surface
        '''
        super().draw(screen, mousePos)

        # Draw the input text on the button
        label = self.getTextObject()
        screen.blit(label, self.getLabelPos(label))

    def doKeyPress(self, event):
        '''
        Handle a key press event on this textbox
        '''
        if event.key == pygame.K_BACKSPACE:
            self.text = self.text[:-1]
        elif event.key != pygame.K_RETURN:
            self.text += event.unicode
