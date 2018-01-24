# Import the API modules
from mod import Mod
from api import network, biome, cmd, dimension, entity, item, properties, vehicle
from api.packets import *

# Import the extra mod data
from mods.default.packets import *
from mods.default.biomes import *
from mods.default.dimension import DefaultChunkProvider
from mods.default.server.entity import bear

import util
from copy import deepcopy

class ServerMod(Mod):
    modName = 'ServerMod'

    def preLoad(self):
        pass

    def load(self):
        # Initialise the packet pipeline
        self.packetPipeline = network.PacketHandler(self.game, util.SERVER)
        # Register the valid packet classes
        packets = [
                    WorldUpdatePacket, SendInventoryPacket,
                    FetchInventoryPacket, SendPlayerImagePacket,
                    FetchPlayerImagePacket
                  ]
        for packet in packets:
            self.packetPipeline.registerPacket(packet)

        # Register the packet handler with the game
        self.gameRegistry.registerPacketHandler(self.packetPipeline)

        # Register the entities
        self.gameRegistry.registerEntity(bear.Bear())

    def postLoad(self):
        # Register the commands
        self.commands = [('/kick', KickPlayerCommand), ('/spawn', SpawnEntityCommand)]
        for comm in self.commands:
            self.gameRegistry.registerCommand(*comm)

        # Initialise the biomes
        self.biomes = [Ocean, Forest, City, Desert]
        # Initialise and register the DimensionHandler accordingly

        dimensionHandler = dimension.DimensionHandler(DefaultChunkProvider(self.biomes, 3), dimension.WorldMP())#self.biomes, 3)
        self.gameRegistry.registerDimension(dimensionHandler)

        # Register the events
        self.gameRegistry.registerEventHandler(onTick, 'onTick')
        self.gameRegistry.registerEventHandler(onDisconnect, 'onDisconnect')

def onTick(game, tick):
    if tick%5 == 0:
        # Send server updates to all of the connected clients 6 times a second
        pp = game.getModInstance('ServerMod').packetPipeline
        for conn in pp.connections.values():
            # Customise the packet for each player
            if conn.username:
                player = game.getPlayer(conn.username)
                packet = WorldUpdatePacket(game.getWorld(player.dimension), player.username)
                pp.sendToPlayer(packet, conn.username)
        # game.getModInstance('ServerMod').packetPipeline.sendToAll(WorldUpdatePacket(game.world), True)

class KickPlayerCommand(cmd.Command):
    def run(self, username, *args):
        pp = self.game.getModInstance('ServerMod').packetPipeline
        # Send a failure message if the user doesn't have elevated privileges
        if username not in open('mods/default/server/elevated_users').read().split('\n')[:-1]:
            pp.sendToPlayer(SendCommandPacket('/message You do not have permission to use that command'), username)
            return

        for player in args:
            # Loop the players, and kick them by deleting the PacketHandler
            # Delete the connection from the server to the client
            pp.closeConnection(player)
            pp.sendToPlayer(DisconnectPacket('You have been kicked from the server.'), player)
            break

class SpawnEntityCommand(cmd.Command):
    def run(self, username, *args):
        entityName = args[0]
        dimensionId = self.game.getPlayer(username).dimension
        try:
            newEntity = self.game.modLoader.gameRegistry.entities[entityName]()
            self.game.getWorld(dimensionId).spawnEntityInWorld(newEntity)
        except KeyError:
            print('[ERROR] Entity does not exist')

def onDisconnect(game):
    '''
    Event Hook: onDisconnect
    Print a little message in the server console
    '''
    print('A Client has disconnected')
