# Impor the Python Standard Libraries
from threading import Thread
import random
import time
import noise
from copy import deepcopy

# Import the mod files
from api.packets import *
from api.biome import *

class DimensionHandler:
    def __init__(self, biomes, biomeSize):
        self.biomes = biomes
        self.biomeSize = biomeSize
        self.worldObj = WorldMP(self)

    def getWorldObj(self):
        '''
        Return a World Object for the dimension
        '''
        return self.worldObj

class WorldMP:
    def __init__(self, dimensionHandler):
        self.entities = []
        self.vehicles = []
        self.players = []

        self.dimHandler = dimensionHandler

        self.world = None

    def generate(self, pos, gameRegistry):
        '''
        Generate the tile map of the world based on the dimensionHandler and position
        '''
        start = time.time()
        xPos, yPos = pos
        xPos = round(xPos)
        yPos = round(yPos)

        # Generate Simplex Noise for the world
        noiseMap = [[noise.snoise2(x, y, 8, 1.4, 0.45, base=gameRegistry.seed)/2+0.5 for x in range(xPos-150, xPos+151)] for y in range(yPos-105, yPos+106)]
        biomeSize = self.dimHandler.biomeSize
        biomeNoise = [[noise.snoise2(x, y, 7, 3, 0.6-(biomeSize*0.1), base=gameRegistry.seed/2)/2+0.5 for x in range(xPos-150, xPos+151)] for y in range(yPos-105, yPos+106)]
        detailNoise = []

        biomes = self.dimHandler.biomes

        # Generate an empty starting biome map
        width, height = (120, 84)
        biomeMap = TileMap(width, height)

        # Scatter some biomes in
        for y, row in enumerate(biomeMap.map):
            for x, tile in enumerate(row):
                biomeMap.map[y][x] = biomes[round(biomeNoise[y][x]*(len(biomes)-1))]

        # Choose tile types and generate entities, houses, trees, etc in the biomes
        biomeMap.finalPass(noiseMap, detailNoise, gameRegistry.resources)
        self.world = biomeMap

        print('Time taken: '+str(time.time()-start)+' seconds')

        return self

    def tickUpdate(self, game):
        '''
        Run one tick of updates on the world and everything in it (SERVER-SIDE UPDATE)
        '''
        # Separate the Game Registry
        gameRegistry = game.modLoader.gameRegistry
        # Loop through the entities and update them
        for e in range(len(self.entities)):
            self.entities[e].onLivingUpdate(game)
            game.fireEvent('onEntityUpdate', self.entities[e])
            # If they die, delete them, and trigger events
            if self.entities[e].isDead:
                entityBackup = self.entities[e]
                del self.entities[e]
                # Trigger on Entity Death events
                game.fireEvent('onEntityDeath', entityBackup, entityBackup.tickDamage)
            elif self.entities[e].tickDamage:
                # Trigger on Entity Damaged events
                game.fireEvent('onEntityDamage', self.entities[e], self.entities[e].tickDamage)

        # Loop through the vehicles and update them
        for v in range(len(self.vehicles)):
            self.vehicles[v].onVehicleUpdate(game)
            game.fireEvent('onVehicleUpdate', self.vehicles[v])
            # If they get destroyed, delete them, and trigger events
            if self.vehicles[v].isDestroyed:
                vehicleBackup = self.vehicles[v]
                del self.vehicles[v]
                # Trigger on Vehicle Destruction events
                game.fireEvent('onVehicleDestroyed', vehicleBackup)

        # Loop through the players and update them
        for p in range(len(self.players)):
            if self.players[p].isDead:
                # If the player has died, disconnect them (because of permadeath)
                game.modLoader.mods['ServerMod'].packetPipeline.sendToPlayer(
                DisconnectPacket('You have died'),
                self.players[p].username)
            elif self.players[p].tickDamage:
                # Trigger on Player Damaged events
                game.fireEvent('onPlayerDamage', self.players[p], self.players[p].tickDamage)

    def getUpdateData(self):
        '''
        Collate the update data into a bytes object
        '''
        return str([p.toBytes() for p in self.players]).replace('"', "'''").encode()

    def handleUpdate(self, updateBytes, game):
        '''
        Use the binary data to update the world
        '''
        # TODO Add entities and vehicles to this.
        # TODO Only fire update events here and handle the actual updates in the client_mod module cod
        players = eval(updateBytes.decode())
        players = [Player.fromBytes(p) for p in players]

        for player in players:
            game.fireEvent("onPlayerUpdate", player, self.players)

    def addPlayer(self, player):
        '''
        Add a player to the world
        '''
        for p in self.players:
            if p.username == player.username:
                return p
        player.pos = [0, 0]
        self.players.append(player)
        return player
