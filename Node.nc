/*
 * ANDES Lab - University of California, Merced
 * This class provides the basic functions of a network node.
 *
 * @author UCM ANDES Lab
 * @date   2013/09/03
 *
 */
#include <Timer.h>
#include "includes/command.h"
#include "includes/packet.h"
#include "includes/CommandMsg.h"
#include "includes/sendInfo.h"
#include "includes/channels.h"

module Node{
   uses interface Boot;

   uses interface SplitControl as AMControl;
   uses interface Receive;

   uses interface SimpleSend as Sender;

   uses interface CommandHandler;
}

implementation{
   pack sendPackage;
   int seq_no[100];

   // Prototypes
   void makePack(pack *Package, uint16_t src, uint16_t dest, uint16_t TTL, uint16_t Protocol, uint16_t seq, uint8_t *payload, uint8_t length);

   event void Boot.booted(){
      call AMControl.start();

      dbg(GENERAL_CHANNEL, "Booted\n");
   }

   event void AMControl.startDone(error_t err){
      int i;
      if(err == SUCCESS){
         dbg(GENERAL_CHANNEL, "Radio On\n");

         for (i=0; i<100; i++)
		seq_no[i] = 100;

      }else{
         //Retry until successful
         call AMControl.start();
      }
   }

   event void AMControl.stopDone(error_t err){}

   event message_t* Receive.receive(message_t* msg, void* payload, uint8_t len){

      dbg(GENERAL_CHANNEL, "Packet Received\n");


      if(len==sizeof(pack)){

         pack* myMsg=(pack*) payload;

// If dest is my TOS_NODE_ID then send a ping reply; else continue flooding;


	if(myMsg->dest == TOS_NODE_ID){

		//dest is my ID so send ping reply.

	}else{

	//It is broadcast so the packet has to be forwarded
	// if the seq number is greater than zero

	if(myMsg->src == TOS_NODE_ID){
		// ignore msgs originated from this node
         dbg(GENERAL_CHANNEL, "Ignoring packet from this node");

		return msg;
	}

	if(seq_no[myMsg->src] < myMsg->seq){
         	dbg(GENERAL_CHANNEL, "Ignoring packet with lesser sequence number\n");
		return msg;
	}

	 seq_no[myMsg->src] = myMsg->seq;

         dbg(GENERAL_CHANNEL, "Package Payload: %s\n", myMsg->payload);
         dbg(GENERAL_CHANNEL, "Package dest: %d\n", myMsg->dest);
         dbg(GENERAL_CHANNEL, "Package src: %d\n", myMsg->src);
         dbg(GENERAL_CHANNEL, "Package sequence number :     : %d\n", myMsg->seq);
         dbg(GENERAL_CHANNEL, "Node id is  : %d\n", TOS_NODE_ID);

	 myMsg->seq = myMsg->seq + 1;
	 myMsg->TTL = myMsg->TTL - 1;

        if(myMsg->TTL > 0){  
	// If the TTL number is still greater than zero then continue to flood
        // retain the src ID of the packet so that destnation knows where the packet came from

             makePack(&sendPackage, myMsg->src, AM_BROADCAST_ADDR, 0, 0, myMsg->seq, myMsg->payload, PACKET_MAX_PAYLOAD_SIZE);

           //  call Sender.send(sendPackage, destination);
             call Sender.send(sendPackage, AM_BROADCAST_ADDR);
        }
         return msg;
	} // else
      }
      dbg(GENERAL_CHANNEL, "Unknown Packet Type %d\n", len);
      return msg;
   }


   event void CommandHandler.ping(uint16_t destination, uint8_t *payload){
      dbg(GENERAL_CHANNEL, "PING EVENT \n");
      dbg(GENERAL_CHANNEL, "RE: Sending it forward to %d \n", destination);
      dbg(GENERAL_CHANNEL, "Forwarding Node id is  : %d\n", TOS_NODE_ID);
    //  makePack(&sendPackage, TOS_NODE_ID, destination, 0, 0, 0, payload, PACKET_MAX_PAYLOAD_SIZE);
     //Flooding: Change destination to be AM_BROADCAST_ADDR always to flood
      makePack(&sendPackage, TOS_NODE_ID, AM_BROADCAST_ADDR, 0, 0, 0, payload, PACKET_MAX_PAYLOAD_SIZE);
      call Sender.send(sendPackage, AM_BROADCAST_ADDR);
   }

   event void CommandHandler.printNeighbors(){}

   event void CommandHandler.printRouteTable(){}

   event void CommandHandler.printLinkState(){}

   event void CommandHandler.printDistanceVector(){}

   event void CommandHandler.setTestServer(){}

   event void CommandHandler.setTestClient(){}

   event void CommandHandler.setAppServer(){}

   event void CommandHandler.setAppClient(){}

   void makePack(pack *Package, uint16_t src, uint16_t dest, uint16_t TTL, uint16_t protocol, uint16_t seq, uint8_t* payload, uint8_t length){
      Package->src = src;
      Package->dest = dest;
      Package->TTL = TTL;
      Package->seq = seq;
      Package->protocol = protocol;
      memcpy(Package->payload, payload, length);
   }
}
