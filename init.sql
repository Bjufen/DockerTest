-- Creating the database
CREATE DATABASE IF NOT EXISTS gs1_db;
USE gs1_db;

-- Creating the Users Table
CREATE TABLE Users (
    UserID INT AUTO_INCREMENT,
    Name VARCHAR(255) NOT NULL,
    Email VARCHAR(255) NOT NULL,
    Type VARCHAR(50) NOT NULL,
    PRIMARY KEY (UserID)
    -- UNIQUE (Email) -- Assuming email addresses are unique for each user
);

-- Creating the Events Table
CREATE TABLE Events (
    EventID INT AUTO_INCREMENT,
    EventName VARCHAR(255) NOT NULL,
    EventTime DATETIME NOT NULL,
    EventPlace VARCHAR(255) NOT NULL,
    OwnerID INT,
    CallID CHAR(36) NOT NULL,
    PRIMARY KEY (EventID),
    FOREIGN KEY (OwnerID) REFERENCES Users(UserID)
    -- This foreign key links to the UserID in the Users table
);

-- Creating the Attendees Table to manage the many-to-many relationship between Users and Events
CREATE TABLE Attendees (
    AttendeeID INT AUTO_INCREMENT,
    UserID INT,
    EventID INT,
    PRIMARY KEY (AttendeeID),
    FOREIGN KEY (UserID) REFERENCES Users(UserID),
    FOREIGN KEY (EventID) REFERENCES Events(EventID)
    -- These foreign keys link to the UserID in the Users table and the EventID in the Events table
);

-- Function to add attendees to an event
DELIMITER $$

CREATE FUNCTION AddAttendeesToEvent(eventID INT, userIDs VARCHAR(255))
    RETURNS VARCHAR(255)
    DETERMINISTIC
BEGIN
    DECLARE userID INT;
    DECLARE end_of_userIDs INT DEFAULT 0;
    DECLARE userIDs_cursor CURSOR FOR
SELECT CAST(SUBSTRING_INDEX(SUBSTRING_INDEX(userIDs, ',', numbers.n), ',', -1) AS UNSIGNED)
FROM (
         SELECT a.n FROM (
                             SELECT ROW_NUMBER() OVER (ORDER BY t1.n) AS n
                             FROM (SELECT 1 AS n UNION ALL SELECT 2 UNION ALL SELECT 3 UNION ALL SELECT 4 UNION ALL SELECT 5 UNION ALL SELECT 6 UNION ALL SELECT 7 UNION ALL SELECT 8 UNION ALL SELECT 9 UNION ALL SELECT 10) t1
                                      CROSS JOIN (SELECT 1 AS n UNION ALL SELECT 2 UNION ALL SELECT 3 UNION ALL SELECT 4 UNION ALL SELECT 5 UNION ALL SELECT 6 UNION ALL SELECT 7 UNION ALL SELECT 8 UNION ALL SELECT 9 UNION ALL SELECT 10) t2
                         ) a
         WHERE a.n <= CHAR_LENGTH(userIDs) - CHAR_LENGTH(REPLACE(userIDs, ',', '')) + 1
     ) numbers
         INNER JOIN (SELECT CONCAT(userIDs, ',') userIDs FROM DUAL) temp
                    ON CHAR_LENGTH(userIDs) - CHAR_LENGTH(REPLACE(userIDs, ',', '')) >= numbers.n - 1;
DECLARE CONTINUE HANDLER FOR NOT FOUND SET end_of_userIDs = 1;

OPEN userIDs_cursor;
userIDs_loop: LOOP
        FETCH userIDs_cursor INTO userID;
        IF end_of_userIDs = 1 THEN
            LEAVE userIDs_loop;
END IF;

        IF EXISTS (SELECT * FROM Events WHERE EventID = eventID) AND
           EXISTS (SELECT * FROM Users WHERE UserID = userID) THEN
            INSERT INTO Attendees (UserID, EventID) VALUES (userID, eventID);
END IF;
END LOOP;
CLOSE userIDs_cursor;

RETURN 'Attendees added';
END$$

CREATE FUNCTION getEventInfo(temp INT)
    RETURNS VARCHAR(1000)
    DETERMINISTIC
BEGIN
    DECLARE eventInfo VARCHAR(1000);
SELECT CONCAT(EventName, ',', EventTime, ',', EventPlace) INTO eventInfo
FROM Events
WHERE EventID = temp;
RETURN eventInfo;
END$$

CREATE FUNCTION getEventAttendees(temp INT)
    RETURNS VARCHAR(255)
    DETERMINISTIC
BEGIN
    DECLARE attendees VARCHAR(255);
SELECT GROUP_CONCAT(UserID) INTO attendees
FROM Attendees
WHERE EventID = temp;
RETURN attendees;
END$$

CREATE FUNCTION getUsersInfo(userIDs VARCHAR(255))
    RETURNS VARCHAR(255)
    DETERMINISTIC
BEGIN
    DECLARE userInfo VARCHAR(255);
SELECT GROUP_CONCAT(CONCAT(Name, ' (', Email, ')') SEPARATOR '; ') INTO userInfo
FROM Users
WHERE FIND_IN_SET(UserID, userIDs) > 0;
RETURN userInfo;
END$$

CREATE FUNCTION getEventDetails(temp INT)
    RETURNS TEXT
    DETERMINISTIC
BEGIN
    DECLARE info VARCHAR(255);
    DECLARE attendeeIDs VARCHAR(255);
    DECLARE attendeeDetails VARCHAR(255);
    DECLARE id CHAR(36);

    -- Get the event CallID
    SELECT CallID INTO id
    FROM Events
    WHERE EventID = temp;

    -- Get the basic event information
    SET info = getEventInfo(temp);

    -- Get the list of attendee IDs
    SET attendeeIDs = getEventAttendees(temp);

    -- If there are no attendees, return just the event info
    IF attendeeIDs IS NULL THEN
        RETURN CONCAT('Event Info: ', info, '; CallID: ', id, '; Attendee Details: NO (ATTTENDEES)');
    END IF;

    -- Get the detailed information of attendees (names and emails)
    SET attendeeDetails = getUsersInfo(attendeeIDs);

    -- Concatenate the event info with the attendee details
RETURN CONCAT('Event Info: ', info, '; CallID: ', id, '; Attendee Details: ', attendeeDetails);
END$$

CREATE FUNCTION getNextEventID()
    RETURNS INT
    DETERMINISTIC
BEGIN
    DECLARE nextEventID INT;
SELECT EventID INTO nextEventID FROM Events
WHERE EventTime > NOW()
ORDER BY EventTime ASC
    LIMIT 1;
RETURN nextEventID;
END$$

CREATE FUNCTION getNextEventDetails()
    RETURNS TEXT
    DETERMINISTIC
BEGIN
    DECLARE nextEventID INT;
    DECLARE nextEventDetails TEXT;
    SET nextEventID = getNextEventID();
    SET nextEventDetails = getEventDetails(nextEventID);
RETURN nextEventDetails;
END$$

DELIMITER ;

INSERT INTO Users (Name, Email, Type) VALUES
('John Doe', 'john.doe@example.com', 'Organizer'),
('Jane Smith', 'jane.smith@example.com', 'Organizer'),
('Alice Johnson', 'alice.johnson@example.com', 'Organizer'),
('Robert Brown', 'robert.brown@example.com', 'Organizer'),

('Emily Turner', 'jusuf11jusuf@gmail.com', 'Guest'),
('Michael Johnson', 'jusuf11jusuf@gmail.com', 'Guest'),
('Sophia Clark', 'jusuf11jusuf@gmail.com', 'Guest'),
('Liam Miller', 'jusuf11jusuf@gmail.com', 'Guest');


INSERT INTO Events (EventTime, CallID, EventPlace, EventName, OwnerID) VALUES
('2024-02-15 10:00:00', UUID(), 'Shopper Experience', 'Galactic Getaway Gala', (SELECT UserID FROM Users WHERE Name = 'John Doe')),
('2024-03-20 09:00:00', UUID(), 'Metaverse Experience', 'Midnight Masquerade Madness', (SELECT UserID FROM Users WHERE Name = 'Jane Smith')),
('2024-04-10 14:30:00', UUID(), 'Technologies Experience', 'Neon Nightscape', (SELECT UserID FROM Users WHERE Name = 'Alice Johnson')),
('2024-05-05 16:00:00', UUID(), 'Innovation Center', 'Enchanted Eclipse Festival', (SELECT UserID FROM Users WHERE Name = 'Robert Brown')),
('2024-06-12 11:00:00', UUID(), 'London', 'Aurora Dreamworld', (SELECT UserID FROM Users WHERE Name = 'John Doe')),
('2024-07-23 13:00:00', UUID(), 'Paris', 'Celestial Symphony Soiree', (SELECT UserID FROM Users WHERE Name = 'Jane Smith')),
('2024-08-15 10:00:00', UUID(), 'Sao Paulo', 'Mystic Mirage Mixer', (SELECT UserID FROM Users WHERE Name = 'Alice Johnson')),
('2024-09-17 15:00:00', UUID(), 'Toronto', 'Retro Rewind Rave', (SELECT UserID FROM Users WHERE Name = 'Robert Brown')),
('2024-10-25 10:30:00', UUID(), 'Melbourne', 'Twilight Tropicana Bash', (SELECT UserID FROM Users WHERE Name = 'John Doe')),
('2024-11-30 12:00:00', UUID(), 'Kapstadt', 'Quantum Quirk Quest', (SELECT UserID FROM Users WHERE Name = 'Jane Smith')),
('2024-12-05 17:00:00', UUID(), 'Tokyo', 'Vintage Vortex Voyage', (SELECT UserID FROM Users WHERE Name = 'Alice Johnson')),
('2025-01-20 18:00:00', UUID(), 'Cologne', 'Cosmic Carnival Craze', (SELECT UserID FROM Users WHERE Name = 'Robert Brown')),
('2025-02-10 19:00:00', UUID(), 'New York', 'Phantom Paradise Party', (SELECT UserID FROM Users WHERE Name = 'John Doe'));


SELECT AddAttendeesToEvent(1, '5,6,7,8');
SELECT AddAttendeesToEvent(2, '5,6,7,8');
SELECT AddAttendeesToEvent(3, '5,6,7,8');
SELECT AddAttendeesToEvent(4, '5,6,7,8');