

-- TRIGGERS (IF TABLE IS DROPPED, THEN TRIGGERS MUST BE CREATED AGAIN)
-- 1) Create a trigger that verifies that only adult card holders check out restricted content.  Assume that I will try to work around your stored procedure for checking out material and try to directly insert a record into the AssetLoans table.

--	2) Create a trigger that verifies that the limit rules on the number of check outs is adhered to (see rules below).

-- RULES ON CHECKOUT:
-- •	Restricted items can only be checked out by members with an adult card
-- •	Check out limits for each card type – i.e. the maximum number of items out at any given time
--			o	Adult cards – maximum of 6
--		    o	Teen cards – maximum of 4
--          o	Children cards – maximum of 2
-- •	An asset cannot be checked out if it is already checked out


CREATE OR ALTER FUNCTION [LibraryProject].doesAssetExist(@thisAssetKey int)
RETURNS INT
AS
BEGIN
	DECLARE @Key int

	IF EXISTS (SELECT AssetKey FROM [LibraryProject].Assets WHERE AssetKey = @thisAssetKey)
		BEGIN
			RETURN 1
		END

	RETURN 0
END
GO



CREATE OR ALTER FUNCTION [LibraryProject].IsAssetAvailable (@thisAssetKey int)
RETURNS INT
AS
BEGIN
	-- DOES ASSET EXIST?

	DECLARE @assetExists int;
	SET @assetExists = [LibraryProject].doesAssetExist(@thisAssetKey);

	IF @assetExists = 0 -- Asset does not exist
		BEGIN
			RETURN 0;
		END



	DECLARE @loanCount int;

	SELECT @loanCount = COUNT(*)
	FROM [LibraryProject].AssetLoans
	WHERE AssetKey = @thisAssetKey	
	

	IF @loanCount IS NOT NULL AND @loanCount > 0
		BEGIN
			DECLARE @returnedDate date;

			-- see if the latest asset loan is returned
			SELECT TOP(1) @returnedDate = ReturnedOn
			FROM [LibraryProject].AssetLoans
			WHERE AssetKey = @thisAssetKey
			ORDER BY AssetLoanKey DESC

			IF @returnedDate IS NOT NULL -- latest loan of asset has been returned
				BEGIN
					RETURN 1
				END
			ELSE
				BEGIN
					RETURN 99
				END
		END

		
		RETURN 1 -- asset has never been checked out, so it's available

END
GO



CREATE OR ALTER FUNCTION [LibraryProject].IsAssetRestricted(@thisAssetKey int)
RETURNS INT
AS
BEGIN
	DECLARE @isRestricted int;

	SELECT 
		@isRestricted = Restricted
	FROM 
		[LibraryProject].Assets
	WHERE 
		AssetKey = @thisAssetKey

	RETURN @isRestricted;
END
GO


CREATE OR ALTER FUNCTION [LibraryProject].passRestrictedAssetCheck(@thisAssetKey int, @thisUserKey int)
RETURNS INT
AS
BEGIN
	IF [LibraryProject].IsAssetRestricted(@thisAssetKey) = 1  
		BEGIN  -- library asset is restricted
			DECLARE @cardType int

			SELECT 
				@cardType = CardTypeKey
			FROM 
				[LibraryProject].Cards
			WHERE 
				UserKey = @thisUserKey 
				AND DeactivatedOn IS NOT NULL


			IF @cardType = 1
				BEGIN -- user is adult
					RETURN 1
				END

			RETURN 0 -- user is not adult
		END
	
	RETURN 1;  -- library asset is not restricted

END
GO



CREATE OR ALTER FUNCTION [LibraryProject].passLimitTest(@thisUserKey int)
RETURNS INT
AS
BEGIN
	--Adult cards – maximum of 6
	--Teen cards – maximum of 4
	--Children cards – maximum of 2

	-- does user have card?
	IF EXISTS(SELECT CardKey FROM [LibraryProject].Cards WHERE UserKey = @thisUserKey AND DeactivatedOn IS NULL)
		BEGIN
		
			-- how many items are checked out?
			DECLARE @checkedOutCount int;

			SELECT @checkedOutCount = COUNT(*)
			FROM [LibraryProject].AssetLoans
			WHERE UserKey = @thisUserKey
			AND ReturnedOn IS NULL
			AND LostOn IS NULL

			IF @checkedOutCount IS NULL -- users don't have any assets checked out
				BEGIN
					RETURN 1
				END


			-- what card type is this?
			DECLARE @cardType int

			SELECT 
				@cardType = CardTypeKey
			FROM 
				[LibraryProject].Cards
			WHERE 
				UserKey = @thisUserKey
				AND DeactivatedOn IS NULL

			IF @cardType = 1
				BEGIN
					-- adult card type
					IF @checkedOutCount < 6
						BEGIN
							RETURN 1
						END
					RETURN 0
				END

			IF @cardType = 2
				BEGIN
					IF @checkedOutCount < 4
						BEGIN
							RETURN 1
						END

					RETURN 0
				END

			IF @cardType = 3
				BEGIN
					IF @checkedOutCount < 2
						BEGIN
							RETURN 1
						END

					RETURN 0
				END
		END


		RETURN 0
	
END
GO


--DROP TRIGGER [LibraryProject].tr_CheckoutAssets;

CREATE OR ALTER TRIGGER [LibraryProject].tr_CheckoutAssets
ON [LibraryProject].AssetLoans
INSTEAD OF INSERT
AS
BEGIN
	SELECT * INTO #TempInsertedTable
	FROM Inserted;

	DECLARE @thisAssetKey int, @thisUserKey int;
	DECLARE @isAvailable int;
	DECLARE @passedRestrictedTest int
	DECLARE @passedLimitTest int;

	WHILE (EXISTS(SELECT AssetKey FROM #TempInsertedTable))
		BEGIN
			
			SELECT TOP (1)
				@thisAssetKey = AssetKey, 
				@thisUserKey = UserKey
			FROM 
				#TempInsertedTable; --Inserted;

			
			SET @isAvailable = [LibraryProject].IsAssetAvailable(@thisAssetKey);
			PRINT 'IS AVAILABLE = ' + CAST(@isAvailable AS varchar(5));
			
			SET @passedRestrictedTest = [LibraryProject].passRestrictedAssetCheck(@thisAssetKey, @thisUserKey);
			PRINT 'PASSED RESTRICTED TEST = ' + CAST(@passedRestrictedTest AS varchar(5));

			SET @passedLimitTest = [LibraryProject].passLimitTest(@thisUserKey);
			PRINT 'PASSED LIMIT TEST = ' + CAST(@passedLimitTest AS varchar(5));

			IF @isAvailable = 1 AND @passedRestrictedTest = 1 AND @passedLimitTest = 1
				BEGIN
					-- check out the asset.
					
					INSERT INTO [LibraryProject].AssetLoans(AssetKey, UserKey, LoanedOn, ReturnedOn, LostOn)		
					SELECT AssetKey, UserKey, LoanedOn, ReturnedOn, LostOn
					FROM Inserted	

					PRINT 'SUCCESSFULLY checked out asset.'
				END
			ELSE
				BEGIN
					PRINT 'CANNOT check out asset.  Reasons could be: asset not available, restricted asset, or checkout limited reached.'
				END

			DELETE FROM #TempInsertedTable WHERE AssetKey = @thisAssetKey;
		END

END
GO

--no replacement cost greater than 29.99
ALTER TABLE LibraryProject.Assets
	ADD CONSTRAINT CHK_Price CHECK (ReplacementCost<=29.99);
--new assettype

--new assets
CREATE PROCEDURE Assets @Asset varchar(100), @AssetDescription varchar(max), @AssetTypeKey int, @ReplacementCost money, @Restricted bit
AS
BEGIN

INSERT LibraryProject.Assets (Asset, AssetDescription, AssetTypeKey, ReplacementCost, Restricted)
VALUES
(@Asset, @AssetDescription , @AssetTypeKey, @ReplacementCost, @Restricted)
END;

--new users and cards
CREATE PROCEDURE UsersInsert @LastName varchar(40), @FirstName varchar(40), @Email varchar(40), @Address1 varchar(40), @Address2 varchar(40), @City varchar(40), @StateAbbreviation varchar(40), @Birthdate date, @ResponsibleUserKey int
AS
BEGIN
INSERT LibraryProject.Users(LastName, FirstName, Email, Address1, Address2, City, StateAbbreviation, Birthdate, ResponsibleUserKey)
VALUES
	(@LastName, @FirstName, @Email, @Address1, @Address2, @City, @StateAbbreviation, @Birthdate, @ResponsibleUserKey)
END

EXEC UsersInsert @LastName='Tyler', @FirstName='Wood', @Email='Twood@yahoo.com', @Address1='1100 West 2290 North', @Address2=NULL, @City='Layton', @StateAbbreviation='UT', @Birthdate='12/24/1969', @ResponsibleUserKey=NULL
EXEC UsersInsert @LastName='Ashton', @FirstName='Wood', @Email='Ashwood@yahoo.com', @Address1='1100 West 2290 North', @Address2=NULL, @City='Layton', @StateAbbreviation='UT', @Birthdate='11/12/2000', @ResponsibleUserKey=1
EXEC UsersInsert @LastName='Kris', @FirstName='Wood', @Email='Kwood@yahoo.com', @Address1='1100 West 2290 North', @Address2=NULL, @City='Layton', @StateAbbreviation='UT', @Birthdate='11/12/2011', @ResponsibleUserKey=1


INSERT LibraryProject.Cards (CardNumber, UserKey, CardTypeKey)
VALUES
	('T2221-422-3181', 7, 1),
	('T1241-233-2934', 8, 2),
	('C1266-553-9901', 9, 3)
	


/*
USE LibraryProject
GO
DROP TRIGGER [LibraryProject].tr_CheckoutAssets;
GO
DROP FUNCTION [LibraryProject].IsAssetAvailable;
GO
DROP FUNCTION [LibraryProject].doesAssetExist;
GO
DROP FUNCTION [LibraryProject]..passRestrictedAssetCheck;
GO
DROP FUNCTION [LibraryProject].IsAssetRestricted
GO
DROP FUNCTION [LibraryProject].passLimitTest;
GO


*/




--Logan's Code
CREATE OR ALTER FUNCTION LibraryProject.FlatFee   
(   @DaysLate INT = 0  )  
RETURNS MONEY  
    BEGIN   
		DECLARE @MoneyDue MONEY
        IF (@DaysLate < 4)
			SET @MoneyDue = 0;
		ELSE IF (@DaysLate < 8)
			SET @MoneyDue = 1.00;
		ELSE IF (@DaysLate < 15)
			SET @MoneyDue = 2.00;
		ELSE
			SET @MoneyDue = 3.00;
        RETURN @MoneyDue 
    END  
; 

CREATE OR ALTER FUNCTION LibraryProject.AllInCost
( @AssetKey INT)
RETURNS MONEY
	BEGIN
		DECLARE @AllInCost INT
		SELECT @AllInCost = A.ReplacementCost
		FROM LibraryProject.Asset A
		WHERE A.AssetKey = @AssetKey
		DECLARE @AssetTypeKey INT
		SELECT @AssetTypeKey = A.AssetTypeKey
		FROM LibraryProject.Asset A
		WHERE A.AssetKey = @AssetKey
		IF (@AssetTypeKey = 1)
			SET @AllInCost = @AllInCost + .99; -- Books
		ELSE IF (@AssetTypeKey = 2)
			SET @AllInCost = @AllInCost + 1.99; -- DVDs
		ELSE IF (@AssetTypeKey = 3)
			SET @AllInCost = @AllInCost + 1.49; --CDs
	RETURN @AllInCost
	END
;

CREATE OR ALTER PROCEDURE InsertAssetType
	@AssetType varChar(50)
AS
BEGIN
	DECLARE @Exists int = 0
	SELECT 
		@Exists = COUNT(A.AssetTypeKey)
	FROM 
		LibraryProject.AssetTypes A
	WHERE 
		A.AssetType = @AssetType
	IF (@Exists = 0)
		BEGIN
			INSERT LibraryProject.AssetTypes (AssetType)
			VALUES (@AssetType)
		END
END;

CREATE OR ALTER PROCEDURE DeactivateAsset
	@AssetKey int
AS
BEGIN
	UPDATE LibraryProject.Assets
	SET DeactivatedOn = GETDATE()
	WHERE AssetKey = @AssetKey
END;

CREATE OR ALTER PROCEDURE DeleteAsset
	@AssetKey int
AS
BEGIN
	DELETE FROM LibraryProject.Assets WHERE AssetKey = @AssetKey;
END;

CREATE OR ALTER PROCEDURE PayFees
	@FeeId int
AS
BEGIN
	UPDATE LibraryProject.Fees
	SET Paid = 1
	WHERE FeeKey = @FeeId
END;


EXEC InserInsertAssetType 'Magazine';
EXEC Assets @Asset='Playboy 12/2011', @AssetDescription= 'Magzine for Men' , @AssetTypeKey=3, @ReplacementCost=9.99, @Restricted=1
EXEC Assets @Asset='Playboy 11/2011', @AssetDescription= 'Magzine for Men' , @AssetTypeKey=3, @ReplacementCost=9.99, @Restricted=1
EXEC Assets @Asset='Venom1', @AssetDescription= 'Spiderman VS Venom' , @AssetTypeKey=1, @ReplacementCost=24.99, @Restricted=0
EXEC Assets @Asset='GQ 8/2016', @AssetDescription= 'Fashion Magzine For Menn' , @AssetTypeKey=3, @ReplacementCost=15.99, @Restricted=0
EXEC Assets @Asset='Pitch Perfect1', @AssetDescription= 'Dance, Comedy, Anna Kendrick' , @AssetTypeKey=1, @ReplacementCost=9.99, @Restricted=0
EXEC Assets @Asset='Magic Mike', @AssetDescription= 'Story of Male Strippers' , @AssetTypeKey=3, @ReplacementCost=9.99, @Restricted=1
EXEC Assets @Asset='La La Land', @AssetDescription= 'What happens in LA...' , @AssetTypeKey=1, @ReplacementCost=12.99, @Restricted=0
EXEC Assets @Asset='Zootopia', @AssetDescription= 'A bunny as a cop in the animal world' , @AssetTypeKey=1, @ReplacementCost=10.99, @Restricted=0
EXEC Assets @Asset='A Brife History Of Time', @AssetDescription= 'A brife introduction of quantum physics' , @AssetTypeKey=2, @ReplacementCost=15.99, @Restricted=0
EXEC Assets @Asset='Titanic', @AssetDescription= 'Oscar winning romantic movie' , @AssetTypeKey=1, @ReplacementCost=9.99, @Restricted=1


--End Logan's Code
											
--Ryan's Code
											
CREATE VIEW feetable AS
SELECT a.asset, LibraryProject.FlatFee(DATEDIFF(DAY,DATEADD(DAY,21,al.LoanedOn),GETDATE())) AS 'Fee'
FROM
	libraryProject.AssetLoans al
		INNER JOIN [LibraryProject].Fees f
		ON al.userkey = f.userkey INNER JOIN LibraryProject.assets a 
		ON a.assetkey = al.assetkey
WHERE DATEDIFF(DAY,DATEADD(DAY,21,al.LoanedOn),GETDATE()) > 0;


CREATE VIEW vt AS
SELECT a.asset, LibraryProject.FlatFee(DATEDIFF(DAY,DATEADD(DAY,21,al.LoanedOn),GETDATE())) AS 'FEE BUCKET', CONCAT(u.FirstName, u.LastName) AS 'something', u.email 
FROM 
	LibraryProject.Users u INNER JOIN LibraryProject.AssetLoans al 
		ON u.userkey = al.userkey  INNER JOIN [LibraryProject].Assets a
		ON al.assetkey = a.assetkey INNER JOIN [LibraryProject].Fees f
		ON u.userkey = f.userkey
WHERE a.AssetTypeKey = 2;

/*SELECT *
FROM feetable
SELECT *
FROM vt
DROP VIEW feetable;
DROP VIEW vt;*/


--End Ryan's Code											
											
											
											
