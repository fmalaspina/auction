// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/// @title Subasta pública
/// @author Fernando Malaspina
/// @notice Este contrato permite ofertar en subastas.
/// Las reglas de la subasta son las siguientes:
/// - No se admiten pujas inferiores a un 5% mayores a la ultima puja.
/// - El precio base de la subasta es 1 ether.
/// - La duración estipulada es de 1 hora.
/// - El plazo de la subasta se extiende en 10 minutos con cada nueva oferta válida. 
/// Esta regla aplica siempre a partir de 10 minutos antes del plazo original de la subasta. 
/// De esta manera los competidores tienen suficiente tiempo para presentar una nueva oferta si así lo desean.
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
    // Estructura para que la devolución de funcion getAllBids sea legible
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
    
    /// @notice Se emite cuando se realiza una nueva puja válida.
    /// @param bidder Dirección del usuario que hizo la puja
    /// @param value  Valor de la puja en wei
    event newBid(address indexed bidder, uint256 value);
    
    /// @notice Se emite cuando la subasta ha finalizado.
    /// @param winnerBidder Dirección del usuario que ganó la subasta
    /// @param winnerBid  Valor de la puja en wei
    event auctionFinnished(address indexed winnerBidder, uint256 winnerBid);

    modifier onlyStillActive() {
        require(block.timestamp <= endDate, "Contrato expirado");
        _;
    }

    modifier onlyOtherThanWinnerBidder() {
        require(msg.sender != winnerBidder, "Usted ya tiene la mejor puja");
        _;
    }

    modifier onlyGreaterBid() {
        require(msg.value > (winnerBid * increment) / 100, "Puja con menos de 5% de incremento sobre la ganadora");
        _;
    }

    /// @notice Permite hacer una nueva puja si cumple las reglas de la subasta
    /// @dev Lanza error si no supera el 5% o si ya es el ofertante ganador
    function bid() onlyStillActive() onlyGreaterBid() onlyOtherThanWinnerBidder external payable  {
        emit newBid(msg.sender, msg.value);
        winnerBidder = msg.sender;
        winnerBid = msg.value;
        if (bids[msg.sender] == 0) {
            bidders.push(msg.sender); // solo agregamos si es la primera vez
        }
        bids[msg.sender] = msg.value;

    }
    
    /// @notice Devuelve todas las pujas realizadas en formato estructurado
    /// @return Una lista de structs con el address del postor y su puja
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


    /// @notice Devuelve el ganador de la subasta y su puja
    /// @return Struct Bid con address y valor ofertado
    function getWinnerBid() external view returns (Bid memory) {
        require(block.timestamp > endDate, "Contrato no finalizado");
        return Bid({bidder: winnerBidder, amount: winnerBid});
    }



}
