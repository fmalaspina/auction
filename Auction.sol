// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;


contract Auction {

    // Comienzo de la puja
    uint256 private startDate;
    // Fin de la puja
    uint256 private endDate;
    // Duracion de la puja
    uint256 private duration;
    // El address del ofertante ganador
    address private winnerBidder;
    // Puja ganadora actual
    uint256 private winnerBid;
    // Incremento requerido entre una puja y otra
    uint256 private increment;
    struct Bid {
        address bidder;
        uint256 amount;
    }
    // Pujas en curso
    mapping(address => uint256) private bids;

    // Array de ofertantes
    address[] private bidders;


    
    
    constructor() {
        startDate = block.timestamp;
        duration = 1 hours;
        endDate = startDate + duration;
        winnerBid = 1 ether;
        increment = 105;
    }

    event newBid(address indexed bidder, uint256 value);

    event end(address indexed bidder, uint256 value);

    // Requiere que la puja esté activa
    modifier onlyStillActive() {
        require(block.timestamp <= endDate, "Contrato expirado");
        _;
    }
    // Requiere que el ofertante sea otro distinto del ganador actual
    modifier onlyOtherThanWinnerBidder() {
        require(msg.sender != winnerBidder, "Usted ya tiene la mejor puja");
        _;
    }

    // Requiere que la oferta supere la anterior en un incremento establecido en constante
    modifier onlyGreaterBid() {
        require(msg.value > (winnerBid * increment) / 100, "Puja con menos de 5% de incremento sobre la ganadora");
        _;
    }

    // Funcion para aceptar la nueva puja
    function bid() onlyStillActive() onlyGreaterBid() onlyOtherThanWinnerBidder external payable  {
        emit newBid(msg.sender, msg.value);
        winnerBidder = msg.sender;
        winnerBid = msg.value;
        if (bids[msg.sender] == 0) {
            bidders.push(msg.sender); // solo agregamos si es la primera vez
        }
        bids[msg.sender] = msg.value;

    }

    // Funcion para devolver todas las pujas hasta el momento
    function getAllBids() external view returns (Bid[] memory) {
        uint256 len = bidders.length;
        Bid[] memory all = new Bid[](len);

        for (uint256 i = 0; i < len; i++) {
            all[i] = Bid({
                bidder: bidders[i],
                amount: bids[bidders[i]]
            });
        }

        return all;
    
   
    } 


    // Devuelve la oferta ganadora
    function getWinnerBid() external view returns (Bid memory) {
        require(block.timestamp > endDate, "Contrato no finalizado");
        return Bid({bidder: winnerBidder, amount: winnerBid});
    }
}
