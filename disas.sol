// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract disas {

    address public owner;

    struct Location {
        string location;
        address account;
        string[] items;
        uint[] quantity;
        uint itemCount;
    }

    struct Donation {
        address donor;
        string[] items;
        uint[] quantity;
        bool donated;
    }

    mapping(uint => Donation) private donations;
    mapping(uint => Location) private data;
    mapping(address => uint) public accountId;
    uint donationCount = 0;

    event DonationEvent(uint donationId, address donor, string[] items, uint[] quantities);
    event ReceiveDonationEvent(uint donationId, address receiver, string[] items, uint[] quantities);
    event DistributeEvent(uint locId, address distributor, string[] items, uint[] quantities);


    modifier onlyOwner() {
        require(msg.sender == owner, "Only the owner can call this function");
        _;
    }
        modifier validateDonationArraysLength(string[] memory items, uint[] memory quantities) {
        require(items.length == quantities.length, "Arrays length mismatch");
        _;
    }

    constructor() {
        owner = msg.sender;
    }

    //fine
    function addLocation(uint id, string memory loc, address account) public onlyOwner {
        require(data[id].itemCount == 0, "Location ID already exists");
        data[id] = Location(loc, account, new string[](0), new uint[](0), 0);
        accountId[account] = id;
    }

    //fine
    function requestItem(string memory itemName, uint qty) public {
        uint loc = accountId[msg.sender];
        Location storage location = data[loc];
        require(msg.sender == location.account, "Not allowed to add items");
        location.items.push(itemName);
        location.quantity.push(qty);
        location.itemCount += 1;
    }

    //fine

    function viewRequestedItem(uint locId) public view returns (string[] memory, uint[] memory) {
        Location storage location = data[locId];
        require(location.account != address(0), "Location does not exist");
        return (location.items, location.quantity);
    }

    //fine
    function donateItems(string[] memory items, uint[] memory quantities) public validateDonationArraysLength(items, quantities) {
        uint donationId = donationCount;
        donationCount += 1;

        Donation storage newDonation = donations[donationId];
        newDonation.donor = msg.sender;
        newDonation.items = items;
        newDonation.quantity = quantities;
        newDonation.donated = false;

        emit DonationEvent(donationId, msg.sender, items, quantities);
    }


    function compare(string memory str1, string memory str2) private  pure returns (bool) {
        if (keccak256(abi.encodePacked(str1)) == keccak256(abi.encodePacked(str2))) {
            return true;
        }
        return false;
    }


    //fine
 function receiveDonation(string memory item) public {
    uint userid = accountId[msg.sender];
    Location storage ldata = data[userid]; 
    string[] storage allitems = ldata.items;
    uint[] storage qty = ldata.quantity;
    bool requested = false;
    uint quantity_required = 0;
    uint index_of_requested_item;

    for(uint i = 0; i < ldata.itemCount; i++){
        if(compare(item, allitems[i])){
            quantity_required = qty[i];
            requested = true;
            index_of_requested_item = i;
            break;
        }
    }

    require(requested, "No request found for the specified item");

    for(uint i = 0; i < donationCount; i++){
        Donation storage d = donations[i];
        string[] memory items = d.items;
        uint[] memory q = d.quantity;

        for(uint j = 0; j < items.length; j++){
            if(compare(item, items[j])){
                if(q[j] >= quantity_required){
                    q[j] -= quantity_required;
                    quantity_required = 0;
                    if(q[j] == 0)
                        break;
                } else if(q[j] < quantity_required) {
                    q[j] = 0;
                    quantity_required -= q[j];
                } 
            }
            if(quantity_required == 0){
                break ;
            }
        }

        emit ReceiveDonationEvent(i, msg.sender, allitems, qty); // Emit inside the loop
    }
 }

        modifier validateDonationId(uint donationId) {
        require(donationId < donationCount, "Invalid donation ID");
        _;
    }

// Enum to represent the status of a donation
enum DonationStatus { Pending, Received, Distributed }

function traceDonatedItem(uint donationId, string memory item) public view validateDonationId(donationId) returns (address donor, uint quantityDonated, address receiver, DonationStatus status) {
    Donation storage donation = donations[donationId];
    require(donation.donor != address(0), "Invalid donation ID");

    string[] memory items = donation.items;
    uint[] memory quantities = donation.quantity;
    require(items.length > 0, "Donation is empty");

    bool itemFound = false;
    uint index;

    for (uint i = 0; i < items.length; i++) {
        if (compare(item, items[i])) {
            itemFound = true;
            index = i;
            break;
        }
    }

    require(itemFound, "Item not found in the donation");

    // Fetch receiver details
    uint receiverLocationId = accountId[msg.sender];
    Location storage receiverLocation = data[receiverLocationId];
    require(receiverLocation.account != address(0), "Receiver location does not exist");

    // Determine the status of the donation
    DonationStatus donationStatus;
    if (quantities[index] > 0) {
        donationStatus = DonationStatus.Pending;
    } else if (quantities[index] == 0 && !donation.donated) {
        donationStatus = DonationStatus.Received;
    } else {
        donationStatus = DonationStatus.Distributed;
    }

    return (donation.donor, quantities[index], receiverLocation.account, donationStatus);
}


    //works fine
    function completedRequest(uint locId) public onlyOwner {
        Location storage location = data[locId];
        require(location.account != address(0), "Location does not exist");
        //require(compareArrays(location.items, location.quantity, location.items, location.quantity), "Distribution data mismatch");
        delete location.items;
        delete location.quantity;
        location.itemCount = 0;
        emit DistributeEvent(locId, location.account, location.items, location.quantity);
    }
}