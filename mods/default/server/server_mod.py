# Import the API modules
from mod import Mod
from api import network, cmd, dimension, item, vehicle
from api.packets import *

# Import the extra mod data
from mods.default.packets import *
from mods.default.biomes import *
from mods.default.dimension import DefaultChunkProvider
from mods.default.server.entity import bear
from mods.default.server.vehicle import horse

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
                    FetchPlayerImagePacket, SendInventoryPacket,
                    FetchInventoryPacket, SendPlayerImagePacket
                  ]
        for packet in packets:
            self.packetPipeline.registerPacket(packet)

        # Register the packet handler with the game
        self.gameRegistry.registerPacketHandler(self.packetPipeline)

        # Register the entities
        self.gameRegistry.registerEntity(bear.Bear())
        self.gameRegistry.registerVehicle(horse.Horse())

    def postLoad(self):
        # Register the commands
        self.commands = [('/kick', KickPlayerCommand), ('/spawn', SpawnEntityCommand), ('/create', ConstructVehicleCommand)]
        for comm in self.commands:
            self.gameRegistry.registerCommand(*comm)

        # Initialise the biomes
        self.biomes = [Ocean, Forest, City, Desert]
        # Initialise and register the DimensionHandler accordingly

        dimensionHandler = dimension.DimensionHandler(DefaultChunkProvider(self.biomes, 3), dimension.WorldMP())
        self.gameRegistry.registerDimension(dimensionHandler)

        # Register the events
        self.gameRegistry.registerEventHandler(onTick, 'onTick')
        self.gameRegistry.registerEventHandler(onPlayerDeath, 'onPlayerDeath')
        self.gameRegistry.registerEventHandler(onPlayerMount, 'onPlayerMount')
        self.gameRegistry.registerEventHandler(onDisconnect, 'onDisconnect')

def onTick(game, tick):
    if tick%(util.FPS//6) == 0:
        # Send server updates to all of the connected clients 6 times a second
        pp = game.packetPipeline
        connections = pp.connections.values()
        for conn in connections:
            # Customise the packet for each player
            if conn.username:
                player = game.getPlayer(conn.username)
                packet = WorldUpdatePacket(game.getWorld(player.dimension), player.username)
                pp.sendToPlayer(packet, conn.username)

def onPlayerMount(game, player, entity, mode):
    '''
    Event Hook: onPlayerMount
    Sync the new player position to the client when the player mounts an entity
    '''
    # If the player is mounting an entity (as opposed to dismounting)
    if mode == 'mount':
        # Set the player position
        player.setPos(entity.pos)

        # Create the sync packet
        packet = ResetPlayerPacket(player)
        # Send the packet
        game.packetPipeline.sendToPlayer(packet, player.username)

def onPlayerDeath(game, player):
    '''
    Event Hook: onPlayerDeath
    Close the connection to the client and
    '''
    # Close the connection to the client from the server
    pp = game.packetPipeline
    pp.sendToPlayer(DisconnectPacket('You have died'), player.username)
    game.packetPipeline.closeConnection(pp.username)
    game.getModInstance('ServerMod').packetPipeline.closeConnection(pp.username)

def onDisconnect(game):
    '''
    Event Hook: onDisconnect
    Print a little message in the server console
    '''
    print('A Client has disconnected')

class KickPlayerCommand(cmd.Command):
    def run(self, username, *args):
        pp = self.game.packetPipeline
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
            newEntity.uuid = self.game.modLoader.getUUIDForEntity(newEntity)
            self.game.getWorld(dimensionId).spawnEntityInWorld(newEntity)
        except KeyError:
            print('[ERROR] Entity does not exist')


class ConstructVehicleCommand(cmd.Command):
    def run(self, username, *args):
        vehicleName = args[0]
        dimensionId = self.game.getPlayer(username).dimension
        try:
            newVehicle = self.game.modLoader.gameRegistry.vehicles[vehicleName]()
            newVehicle.uuid = self.game.modLoader.getUUIDForEntity(newVehicle)
            self.game.getWorld(dimensionId).spawnEntityInWorld(newVehicle, 'vehicle')
        except KeyError:
            print('[ERROR] Vehicle does not exist')
