from api.item import Inventory

class Player:
    def __init__(self):
        self.username = ''
        self.pos = [0, 0]
        self.inventory = Inventory()
        self.isDead = False

    def setUsername(self, name):
        '''
        Set the player username to a given name
        '''
        self.username = name

    def toBytes(self):
        return b'player'

    @staticmethod
    def fromBytes(self):
        return Player()

class Entity:
    def __init__(self):
        pass
