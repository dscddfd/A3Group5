CREATE SCHEMA LibraryProject;
GO

CREATE TABLE LibraryProject.Users
(
	UserKey int IDENTITY(1,1) PRIMARY KEY NOT NULL,
	LastName varchar(40) NOT NULL,
	FirstName varchar(40) NOT NULL,
	Email varchar(50) NOT NULL,
	Address1 varchar(50) NOT NULL,
	Address2 varchar(30) NULL,
	City varchar(30) NOT NULL,
	StateAbbreviation char(2) NOT NULL,
	Birthdate date NOT NULL,
	ResponsibleUserKey int NULL,
	CreatedOn datetime DEFAULT(GETDATE()) NOT NULL,
	DeactivatedOn datetime NULL
)

SET IDENTITY_INSERT LibraryProject.Users ON 

INSERT LibraryProject.Users(UserKey, LastName, FirstName, Email, Address1, Address2, City, StateAbbreviation, Birthdate, ResponsibleUserKey)
VALUES
	(1, 'Smith', 'Taylor', 'TSmith@yahoo.com', '123 West Avenue', NULL, 'Ogden', 'UT', '2/14/1979', NULL),
	(2, 'Smith', 'Madison', 'MSmith@yahoo.com', '123 West Avenue', NULL, 'Ogden', 'UT', '8/26/2002', 1),
	(3, 'Smith', 'Brooklyn', 'BrSmith@yahoo.com', '123 West Avenue', NULL, 'Ogden', 'UT', '10/19/2006', 1),
	(4, 'Smith', 'Jordan', 'JoSmith@yahoo.com', '123 West Avenue', NULL, 'Ogden', 'UT', '5/21/2012', 1),
	(5, 'Durden', 'Tyler', 'TyDurden@gmail.com', '1537 Paper Street', 'Suite 2', 'North Ogden', 'UT', '11/04/1975', NULL),
	(6, 'Soze', 'Keyser', 'KSoze@gmail.com', '1818 Code Way', NULL, 'West Haven', 'UT', '06/22/1968', NULL)

SET IDENTITY_INSERT LibraryProject.Users OFF

CREATE TABLE LibraryProject.CardTypes
(
	CardTypeKey int IDENTITY(1,1) PRIMARY KEY NOT NULL,
	CardType varchar(50)
)

SET IDENTITY_INSERT LibraryProject.CardTypes ON 

INSERT LibraryProject.CardTypes (CardTypeKey, CardType)
VALUES
	(1, 'Adult'),
	(2, 'Teen'),
	(3, 'Child')

SET IDENTITY_INSERT LibraryProject.CardTypes OFF

CREATE TABLE LibraryProject.Cards
(
	CardKey int IDENTITY(1,1) PRIMARY KEY NOT NULL,
	CardNumber char(14) NOT NULL,
	UserKey int NOT NULL,
	CardTypeKey int NOT NULL,
	CreatedOn datetime DEFAULT(GETDATE()) NOT NULL,
	DeactivatedOn datetime NULL
)

SET IDENTITY_INSERT LibraryProject.Cards ON 

INSERT LibraryProject.Cards (CardKey, CardNumber, UserKey, CardTypeKey, DeactivatedOn)
VALUES
	(1, 'A1251-432-2288', 1, 1, '10/29/2018'),
	(2, 'T1241-233-2934', 2, 2, NULL),
	(3, 'C1266-553-9901', 3, 3, NULL),
	(4, 'C1266-553-9902', 4, 3, NULL),
	(5, 'A1251-432-2289', 5, 1, NULL),
	(6, 'A1251-432-2293', 6, 1, NULL),
	(7, 'A1251-432-2299', 1, 1, NULL)

SET IDENTITY_INSERT LibraryProject.Cards OFF

CREATE TABLE LibraryProject.AssetTypes
(
	AssetTypeKey int IDENTITY(1,1) PRIMARY KEY NOT NULL,
	AssetType varchar(50)
)

SET IDENTITY_INSERT LibraryProject.AssetTypes ON 

INSERT LibraryProject.AssetTypes (AssetTypeKey, AssetType)
VALUES
	(1, 'Movie'),
	(2, 'Book')

SET IDENTITY_INSERT LibraryProject.AssetTypes OFF

CREATE TABLE LibraryProject.Assets
(
	AssetKey int IDENTITY(1,1) PRIMARY KEY NOT NULL,
	Asset varchar(100),
	AssetDescription varchar(max),
	AssetTag uniqueidentifier DEFAULT(NEWID()) NOT NULL,
	AssetTypeKey int NOT NULL,
	ReplacementCost money NOT NULL,
	Restricted bit NOT NULL DEFAULT(0),
	CreatedOn datetime DEFAULT(GETDATE()) NOT NULL,
	DeactivatedOn datetime NULL
)

SET IDENTITY_INSERT LibraryProject.Assets ON 

INSERT LibraryProject.Assets (AssetKey, Asset, AssetDescription, AssetTypeKey, ReplacementCost, Restricted)
VALUES
	(1, 'OathBringer', 'Book 3 of the Stormlight Archives by Brandon Sanderson', 2, 24.19, 0),
	(2, 'Mistborn', 'First book in the Mistborn trilogy by Brandon Sanderson', 2, 9.89, 0),
	(3, 'Fight Club', 'Rated R movie staring Brad Pit and Edward Norton', 1, 14.99, 1),
	(4, 'The Giving Tree', 'A timeless classic about a relationship between a boy and a tree', 2, 20.99, 0),
	(5, 'Giraffes Can''t Dance', 'A children''s book about the love of dance', 2, 6.99, 0),
	(6, 'Fahrenheit 451', 'A dystopian future where books are burned', 2, 18.99, 0),
	(7, 'A Clockwork Orange', 'A book by Anthony Burgess set in a dystopian future', 2, 23.99, 1),
	(8, 'The Fifth Element', 'The best Sci-fi movie in the last 20 years', 1, 14.99, 0)

SET IDENTITY_INSERT LibraryProject.Assets ON 

CREATE TABLE LibraryProject.AssetLoans
(
	AssetLoanKey int IDENTITY(1,1) PRIMARY KEY NOT NULL,
	AssetKey int NOT NULL,
	UserKey int NOT NULL,
	LoanedOn date NOT NULL,
	ReturnedOn date NULL,
	LostOn date NULL
)

INSERT LibraryProject.AssetLoans (AssetKey, UserKey, LoanedOn, ReturnedOn, LostOn)
VALUES
	(1, 5, '9/15/2018', '10/26/2018', NULL),
	(2, 5, '9/15/2018', NULL, NULL),
	(1, 6, '10/27/2018', NULL, NULL),
	(8, 1, '10/15/2018', NULL, NULL)

CREATE TABLE LibraryProject.Fees
(
	FeeKey int IDENTITY(1,1) PRIMARY KEY NOT NULL,
	Amount money NOT NULL,
	UserKey int NOT NULL,
	Paid bit DEFAULT(0) NOT NULL
)

INSERT LibraryProject.Fees (Amount, UserKey) VALUES (3.00, 5)

ALTER TABLE LibraryProject.Fees
ADD CONSTRAINT fk_UserKey FOREIGN KEY (UserKey)
	REFERENCES LibraryProject.Users(UserKey)

ALTER TABLE LibraryProject.Cards
ADD CONSTRAINT fk_CardType FOREIGN KEY (CardTypeKey)
	REFERENCES LibraryProject.CardTypes(CardTypeKey) 

ALTER TABLE LibraryProject.Cards
ADD CONSTRAINT fk_UserCards FOREIGN KEY (UserKey)
	REFERENCES LibraryProject.Users(UserKey)

ALTER TABLE LibraryProject.Users
ADD CONSTRAINT fk_ResponsibleUser FOREIGN KEY (ResponsibleUserKey)
	REFERENCES LibraryProject.Users(UserKey)

ALTER TABLE LibraryProject.Assets
ADD CONSTRAINT fk_AssetType FOREIGN KEY (AssetTypeKey)
	REFERENCES LibraryProject.AssetTypes(AssetTypeKey)

ALTER TABLE LibraryProject.AssetLoans
ADD CONSTRAINT fk_UserLoans FOREIGN KEY (UserKey)
	REFERENCES LibraryProject.Users(UserKey)

ALTER TABLE LibraryProject.AssetLoans
ADD CONSTRAINT fk_AssetLoaned FOREIGN KEY (AssetKey)
	REFERENCES LibraryProject.Assets(AssetKey)




/*

DROP TABLE LibraryProject.AssetLoans
DROP TABLE LibraryProject.Assets
DROP TABLE LibraryProject.AssetTypes
DROP TABLE LibraryProject.Cards
DROP TABLE LibraryProject.CardTypes
DROP TABLE LibraryProject.Users
DROP SCHEMA LibraryProject
*/
