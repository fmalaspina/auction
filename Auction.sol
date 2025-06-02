// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/// @title Subasta pública
/// @author Fernando Malaspina
/// @notice Este contrato permite ofertar en subastas.
/// @dev Las reglas de la subasta son las siguientes:
/// - No se admiten pujas inferiores a un 5% mayores a la ultima puja.
/// - El precio base de la subasta es 1 ether.
/// - La duración estipulada es de 1 hora.
/// - El plazo de la subasta se extiende en 10 minutos con cada nueva oferta válida. 
/// Esta regla aplica siempre a partir de 10 minutos antes del plazo original de la subasta. 
/// De esta manera los competidores tienen suficiente tiempo para presentar una nueva oferta si así lo desean.
contract Auction {
    address public immutable owner;
    uint256 public immutable startDate;
    uint256 public endDate;
    uint256 public immutable duration;
    address private winnerBidder;
    uint256 private winnerBid;
    uint256 public immutable increment;
    uint256 public immutable extension;
    uint256 public immutable gasFee;
    struct Bid {
        address bidder;
        uint256 amount;
    }
    mapping(address => uint256) private bids;
    bool public finalized;
    address[] private bidders;


    bool locked; 
    
    constructor() {
        owner = msg.sender;
        startDate = block.timestamp;
        duration = 15 minutes;
        endDate = startDate + duration;
        winnerBid = 0.95 ether;
        increment = 5;
        finalized = false;
        extension = 10 minutes;
        gasFee = 2;
    }
    
    /// @notice Se emite cuando se realiza una nueva puja válida.
    /// @param bidder Dirección del usuario que hizo la puja
    /// @param value  Valor de la puja en wei
    event NewBid(address indexed bidder, uint256 value);
    
    /// @notice Se emite cuando la subasta ha finalizado.
    /// @param winnerBidder Dirección del usuario que ganó la subasta
    /// @param winnerBid  Valor de la puja en wei
    event AuctionFinished(address indexed winnerBidder, uint256 winnerBid);

    /// @notice Finalización de la subasta extendida.
    /// @param bidder Dirección del ofertante
    /// @param newEndTime Nueva fecha de fin de subasta
    /// @param bidAmount Valor de la puja
    event AuctionExtended(address indexed bidder, uint256 newEndTime, uint256 bidAmount);

    /// @notice Reclamo de fondos
    /// @param bidder Dirección del ofertante
    /// @param claimedAmount Valor de la puja menos 2% de gas
    event Refund(address indexed bidder, uint256 claimedAmount);

    /// @notice Reclamos parcial automático (mejora a la propuesta en la consigna)
    /// @param bidder Dirección del ofertante
    /// @param refundAmount Valor por sobre la puja menos 2% de gas
    event PartialRefund(address indexed bidder, uint256 refundAmount);

    modifier onlyNotFinalized {
        require(!finalized, "Already finalized" );
        _;
    }

    modifier onlyFinalized {
        require(finalized, "Not finalized yet." );
        _;
    }

    modifier nonReentrant { 
        require(!locked, "reentr."); 
        locked = true; 
        _; 
        locked = false; 
    }

    modifier onlyStillActive() {
        require(block.timestamp < endDate, "Contrato expirado");
        _;
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "Solo el owner puede finalizar la subasta.");
        _;
    }


    modifier onlyFinished() {
        require(block.timestamp >= endDate, "El contrato aun no ha expirado");
        _;
    }

    modifier onlyOtherThanWinnerBidder() {
        require(msg.sender != winnerBidder, "Usted ya tiene la mejor puja");
        _;
    }

    modifier onlyGreaterBid() {
        require(msg.value > (winnerBid * (increment+100)) / 100, "Puja con menos de 5% de incremento sobre la ganadora");
        _;
    }

    /// @notice Permite hacer una nueva puja si cumple las reglas de la subasta
    /// @dev Lanza error si no supera el 5% o si ya es el ofertante ganador
    function bid() nonReentrant onlyStillActive onlyGreaterBid onlyOtherThanWinnerBidder external payable  {
        emit NewBid(msg.sender, msg.value);
        winnerBidder = msg.sender;
        winnerBid = msg.value;
        if (bids[msg.sender] == 0) {
            bidders.push(msg.sender); // solo agregamos si es la primera vez
        }
        uint256 previousAmount = bids[msg.sender];
        uint256 refundAmount = (previousAmount * (100 - gasFee)) / 100;
        bids[msg.sender] = msg.value;
        if (block.timestamp >= endDate - extension) {
            uint256 newEndTime = endDate + extension;
            endDate = newEndTime;
            emit AuctionExtended(msg.sender,newEndTime,msg.value);
        }
        (bool sent, ) = payable(msg.sender).call{value: refundAmount}("");
        require(sent, "Refund fallido");
        emit PartialRefund(msg.sender, refundAmount);

    }
    
    
    /// @notice Devuelve todas las pujas realizadas en formato estructurado
    /// @return Bid[] Una lista de structs con el address del postor y su puja
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

    /// @notice Devuelve el tiempo hasta finalizar la subasta
    /// @return uint256 timeLeft
    function getTimeLeft() external view returns (uint256) {
        
        if (block.timestamp >= endDate) {
            return 0;
        }
        return  endDate - block.timestamp;
        
    }

    /// @notice Devuelve la oferta ganador de la subasta y su puja hasta el momento
    /// @return Struct Bid con address y valor ofertado
    function getWinnerBid() external view returns (Bid memory) {
        return Bid({bidder: winnerBidder, amount: winnerBid});
       
    }

    /// @dev Deberia tener modifier onlyOwner, pero se deja sin para que los profes puedan probar la finalizacion
    function finalize() external onlyOwner onlyFinished onlyNotFinalized nonReentrant {
        finalized = true;
        emit AuctionFinished(winnerBidder, winnerBid);   // <- aquí
    }

    /// @notice Reclama el dinero ofertado menos 2% de gas
    function claim() external nonReentrant onlyFinished onlyOtherThanWinnerBidder {        
        uint256 bidAmount = bids[msg.sender];
        require(bidAmount > 0, "No hay oferta realizada");
        uint256 refundAmount = (bidAmount * (100 - gasFee)) / 100;
        delete bids[msg.sender];
        for (uint i = 0; i < bidders.length; i++) {
            if (bidders[i] == msg.sender) {
                bidders[i] = bidders[bidders.length - 1]; // move last to current
                bidders.pop(); // remove last
                break;
            }
        }
        (bool sent, ) = payable(msg.sender).call{value: refundAmount}("");
        require(sent, "Refund fallido");
        emit Refund(msg.sender,refundAmount);  
    }

    function withdrawRemaining() external onlyOwner onlyFinalized {
        uint256 balance = address(this).balance;
        require(balance > 0, "No hay fondos remanentes para retirar");

        (bool sent, ) = payable(owner).call{value: balance}("");
        require(sent, "Transferencia fallida");
    }
}
