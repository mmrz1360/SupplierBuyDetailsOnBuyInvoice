declare  @date datetime  = getdate()




SELECT I.ItemID,I.Name,I.Barcode,UnitOfMeasure,I.DepartmentName
INTO #ITEM 
FROM ItemForMobileView  AS I WHERE  LanguageID = 314 

/*********************آخرین قیمت فروش شعب*****************/
;with cte_A as  (
select s.StoreID ,itemid,EffectiveDate,PriceAmount,ConsumerPrice from (

select RN = row_number() over (partition by iv.StoreID ,iv.ItemID order by  iv.EffectiveDate desc) ,
iv.StoreID ,iv.ItemID ,iv.EffectiveDate,PriceAmount,iv.ConsumerPrice from ItemSalePriceView as iv 
where  ReasonID = 16
) AA inner  join dbo.Store as S on s.StoreID = aa.StoreID
or  AA.StoreID is null
where  rn = 1 ) , cte_final as (

select Storeid,itemid,PriceAmount,ConsumerPrice,r= row_number() over (partition by StoreID ,ItemID order by  EffectiveDate desc)
from cte_A )

select Storeid,itemid,PriceAmount,ConsumerPrice
into #price
from cte_final as F where  f.r = 1 
/*********************آخرین قیمت مصوب*****************/

;WITH cte
AS (SELECT 
           SC.SupplierID,
           SC.EffectiveDate,
     C.Date,
           SCI.ItemID,
           SCI.Amount,
           SCI.LastCost,
     SC.ContractNumber,
	 SCI.CurrentPrice AS ContractPriceAmount ,
	 SCI.ConsumerPrice as ContractConsumerPrice ,
           ROW_NUMBER() OVER (PARTITION BY SC.SupplierID,
                                           SCI.ItemID
                              ORDER BY SC.EffectiveDate DESC
                             ) AS RowNumber
    FROM dbo.SupplierContract SC WITH (NOLOCK)
        INNER JOIN dbo.SupplierContractLineItems SCI WITH (NOLOCK)
            ON SC.ContractID = SCI.ContractID
 INNER JOIN Calendar C
  ON C.BusinessDate=CAST(SC.EffectiveDate AS DATE)
  WHERE ISNULL(C.LanguageID,314)=314
  AND SC.StatusID=246
    ) 
 SELECT * INTO #Contract FROM CTE
 WHERE RowNumber=1
 /*****************************************************************************************************/
;WITH CTE_SaleQuantity AS (
SELECT SL.StockID,SL.ItemID,SUM(SL.Quantity) AS SaleQuantity  FROM dbo.SaleInvoice S
INNER JOIN dbo.SaleInvoiceLineItem SL
ON SL.InvoiceID = S.InvoiceID
WHERE SL.StockID IN ($StockID)
AND S.InvoiceDate BETWEEN '$StartDate' AND '$EndDate'
GROUP BY SL.StockID,SL.ItemID)

SELECT * INTO #CTE_SaleQuantity FROM CTE_SaleQuantity
/*****************************************************************************************************/ 

DECLARE @start AS CHAR(10)  =  (SELECT dbo.ConvertToJalaliDate ( cast('$StartDate' AS DATE)))
,       @end  AS CHAR (10)  =  (SELECT dbo.ConvertToJalaliDate ( cast('$EndDate' AS DATE)))  ;

SELECT  -- DISTINCT 
 dbo.ConvertToJalaliDate(D.DocumentDate) AS 'تاریخ سند' ,
  CAST(D.BookerStoreID AS NVARCHAR(10)) +'_'+ 
  CAST(D.BookerWorkstationID AS NVARCHAR(10)) +'_'+ 
  CAST(D.DocumentID AS NVARCHAR(50)) AS ID, 
  [ تاریخ شروع گزارش] = @start ,
  [تاریخ پایان گزارش] = @end ,
  Case when d.StatusID=246 then N'فعال'
  WHEN D.StatusID=247 THEN N'ابطالی'
  ELSE N'-' END AS [وضعیت فاکتور],
  UAPP.DISPLAYNAME [کاربر تایید کننده],
  UVID.DISPLAYNAME [کاربر ابطال کننده],
  DV.Name AS  [نوع فاکتور],
  DD.Name  [دپارتمان],DSection.Name [سکشن],DF.Name [فمیلی] , IDA.Name AS [ساب فمیلی],
  C.Date as [تاریخ سند2 ],
  SDLICF.SupplierSumQuantity as [تعداد تامین کننده],
  SDLICF.SupplierSumCost as [جمع مبلغ تامین کننده],
D.Comment [توضیحات],
  I.UnitOfMeasure,
  CR.Date as [تاریخ رسید / حواله],
  D.DocumentCode [شماره سند],
  SDR.DocumentCode [شماره رسید/حواله],
  D.SupplierID, SV.Name AS SupplierName,
  I.ItemID, I.Name AS ItemName, Barcode, DI.NegativeCost AS [مبلغ کاهنده] , DI.PositiveCost AS [مبلغ افزاینده] ,
  
  
  ISNULL( DI.UnitCount,0) + ( ISNULL (DI.PackCount,0) *  ISNULL (di.PackUnitCount,0))  as [تعداد خرید], 
  ISNULL (DI.BonusCount,0) AS [تعداد جایزه],
  ISNULL (DI.Cost,0) AS [بهای خرید],
  ISNULL (DI.SalePrice,0) AS [مبلغ فروش زمان ثبت سند],
  ( DI.Discount + DI.SupplierDiscount + Discount1 + Discount2 + Discount3 + Discount4 + Discount5) AS  [جمع تخفیفات],
  FORMAT(( ISNULL (DI.Tax ,0 )+  ISNULL (DI.Toll ,0)),'###' )  as  [جمع مالیات و عوارض] ,
  D.TargetStockID ,SS.Name  AS  [ شعبه], 
  DI.NetCost , 
  (DI.NetCost + (DI.Tax + DI.Toll ) ) as  [مبلغ قابل پرداخت],
  PRC.PriceAmount [مبلغ فروش],
  PRC.ConsumerPrice [قیمت مصرف کننده],
  /**********************اطلاعات مربوط به مصوب*****************/
    ISNULL(SC.Amount,0) [آخرین قیمت مصوب]  ,
    ISNULL(SC.LastCost,0) [قیمت مصوب قبلی] ,
    SC.Date [تاریخ مصوب],
    CAST(CAST(SC.EffectiveDate AS TIME ) AS NVARCHAR(8)) [ساعت مصوب],
 ContractNumber [شماره سند مصوبه],
 DI.SupplierCost [قیمت تامین کننده],D.InvoiceNumber [شماره فاکتور تامین کننده],
 D.FinanceDocumentCode [شماره مرجع حسابداری],
 CASE WHEN  ISNULL(D.FinanceDocument,0) =1 THEN N'صادر شده' ELSE CASE WHEN D.StatusID=246 THEN  N'عدم صدور' ELSE N'سند ابطالی' END  END AS [وضعیت سند حسابداری],
/* اطلاعات مربوط به صادر کننده اسناد */
LEFT(CAST(FX.ExportDate AS TIME),8) [ساعت صدور سند],
CFX.DATE [تاریخ صدور سند ],
UFX.DisplayName [کاربر صادر کننده سند]
,SaleQuantity.SaleQuantity AS [فروش در بازه گزارش]
,SC.ContractPriceAmount AS [قیمت فروش مصوب	] 
,sc.ContractConsumerPrice AS [قیمت مصرف کننده مصوب]
INTO #Report

FROM dbo.StockDocument D WITH (NOLOCK) 
INNER JOIN dbo.StockDocumentLineItem DI WITH (NOLOCK) 
  ON D.BookerStoreID = DI.BookerStoreID AND 
  D.BookerWorkstationID = DI.BookerWorkstationID AND 
  D.DocumentID = DI.DocumentID

LEFT JOIN StockDocumentLineItemCustomDiscount SILICD WITH (NOLOCK) 
  ON SILICD.DocumentID = DI.DocumentID 
  AND SILICD.LineItemID = DI.LineItemID
  AND SILICD.BookerStoreID  = DI.BookerStoreID 
  AND SILICD.BookerWorkstationID= DI.BookerWorkstationID

  LEFT JOIN StockDocumentLineItemCustomField SDLICF
  ON D.DocumentID = SDLICF.DocumentID AND
  D.BookerStoreID = SDLICF.BookerStoreID AND
  D.BookerWorkstationID = SDLICF.BookerWorkstationID

--INNER  JOIN StockDocumentReference AS SR  WITH (NOLOCK) 
LEFT JOIN StockDocumentReference AS SR  WITH (NOLOCK) 
  ON SR.DocumentID = D.DocumentID

LEFT JOIN StockDocument SDR WITH (NOLOCK) 
  ON SDR.DocumentID=SR.ReferDocumentID
INNER JOIN SupplierView SV WITH (NOLOCK) 
 ON SV.SupplierID=D.SupplierID
 AND ISNULL(SV.LanguageID,314)=314
INNER JOIN Stock ST WITH (NOLOCK) 
 ON ST.StockID=D.TargetStockID
INNER JOIN Store  AS SS  WITH (NOLOCK) 
 ON SS.StoreID=ST.StoreID
INNER JOIN #ITEM I WITH (NOLOCK) 
 ON DI.ItemID = I.ItemID
LEFT JOIN [USER] UAPP with (nolock)
 ON UAPP.USERID=D.ApproveUser
LEFT JOIN [USER] UVID with (nolock)
 ON UVID.USERID=D.VoidUser
 LEFT JOIN Calendar C with (nolock)
 ON C.BusinessDate=D.BusinessDate
 AND ISNULL(C.LanguageID,314)=314
LEFT JOIN Calendar CR with (nolock)
 ON CR.BusinessDate=SDR.BusinessDate
 AND ISNULL(CR.LanguageID,314)=314
INNER JOIN DictionaryView DV
 ON DV.DictionaryID=D.DocumentTypeID
 AND ISNULL(DV.LanguageID,314)=314

LEFT JOIN #price PRC
 ON PRC.ItemID=DI.ItemID
 AND PRC.StoreID=SS.StoreID

LEFT JOIN #Contract SC
 ON SC.SupplierID=D.SupplierID
 AND SC.ItemID=DI.ItemID
 
 /******************************************/
 LEFT JOIN #CTE_SaleQuantity SaleQuantity
  ON SaleQuantity.ItemID = DI.ItemID
 AND SaleQuantity.StockID = D.TargetStockID
 /******************************************/
 /*اطلاعات مربوط به دپارتمان ها*/
LEFT JOIN ItemDepartmentAssignmentView IDA
    ON IDA.ItemID = DI.ItemID
 AND IDA.TYPEID=1
LEFT JOIN Department DSF
 ON DSF.DepartmentID=IDA.DepartmentID
LEFT JOIN Department  DF 
 ON DSF.ParentID=DF.DepartmentID
LEFT JOIN Department  DSection 
 ON DF.ParentID=DSection.DepartmentID
LEFT  JOIN Department DD
 ON DSection.ParentID=DD.DepartmentID
/******************************************************************/
/*اطلاعات مربوط به صادر کننده سند */
LEFT JOIN ExportDataConfig EDC 
 ON EDC.TypeID=D.DocumentTypeID
 AND EDC.TypeID IN (433,434)
LEFT JOIN FinancialExports FX
 ON FX.OperationID=EDC.ID
 AND RIGHT(FX.DocumentID,36) =CAST(D.DocumentID AS nvarchar(36))
-- AND CAST(RIGHT(FX.DocumentID,36) AS uniqueidentifier)=D.DocumentID
LEFT JOIN [USER] UFX
 ON UFX.UserID=FX.UserID 
LEFT JOIN  Calendar CFX
 ON CFX.BusinessDate=CAST(FX.ExportDate AS date)  AND ISNULL(CFX.LanguageID,314)=314
/******************************************************************/
WHERE D.StatusID IN ( 246)
 AND D.DocumentTypeID in ( 433,434)
 -- AND SDR.DocumentTypeID IN (296,297)
 AND D.DocumentDate BETWEEN '$StartDate' AND '$EndDate'
 AND DI.ItemID IN ($ItemID)
 AND D.SupplierID IN ($SupplierID)
 AND D.TargetStockID IN ($StockID)

 /******************************/



 SELECT  * FROM #Report

 UNION ALL
/*
 DECLARE @start AS CHAR(10)  =  (SELECT dbo.ConvertToJalaliDate ( cast('2021/07/08 00:00:00' AS DATE)))
,       @end  AS CHAR (10)  =  (SELECT dbo.ConvertToJalaliDate ( cast('2021/07/08 23:59:59' AS DATE)))  ;
*/
select  DISTINCT 
       dbo.ConvertToJalaliDate(sd.DocumentDate) ,
 NULL, 
  dbo.ConvertToJalaliDate ( cast('$StartDate' AS DATE)) ,
  dbo.ConvertToJalaliDate ( cast('$EndDate' AS DATE)) ,
 NULL,NULL, NULL,NULL, NULL,NULL,NULL ,NULL,
  C.Date as [تاریخ سند1 ],
  NULL,
  NULL,
  NULL,
  NULL,
  NULL,
  sd.DocumentCode [شماره سند],
 NULL,
 NULL,NULL,
  NULL, DTT.Name, NULL,
    sum(case when  f.ChangeAmountTypeID in (287,288) then NetAmount else  0 end ) as  NegativeCost ,
  sum( case when  f.ChangeAmountTypeID in (289,290) then NetAmount else  0 end )  as PositiveCost ,

   NULL,NULL, NULL, NULL, NULL, 0, NULL ,NULL, 
  isnull(sum( case when  f.ChangeAmountTypeID in (289,290) then NetAmount else  0 end ),0) - isnull(sum(case when  f.ChangeAmountTypeID in (287,288) then NetAmount else  0 end ),0) as  NetCost, 
  isnull(sum( case when  f.ChangeAmountTypeID in (289,290) then NetAmount else  0 end ),0) - isnull(sum(case when  f.ChangeAmountTypeID in (287,288) then NetAmount else  0 end ),0),  0,  0,
  /**********************اطلاعات مربوط به مصوب*****************/
    NULL,    NULL,    NULL,    NULL,NULL,NULL,NULL,NULL,NULL,
/* اطلاعات مربوط به صادر کننده اسناد */
NULL,NULL,NULL,0,0,0
  from  StockDocument as sd 
  --INNER JOIN #Report RE
  --ON sd.DocumentID = RIGHT(re.id , 36)
 left  join  StockDocumentCostModifier as f with  (nolock)
 on sd.DocumentID= f.DocumentID
 left  join   DictionaryTranslations as dt 
  on dt.DictionaryID =  sd.DocumentTypeID and  dt.LanguageID = 314
 
 left  join   DictionaryTranslations as dtt 
  on dtt.DictionaryID =  f.ChangeAmountTypeID and  dtt.LanguageID = 314
 left  join  dbo.Calendar as c 
  on c.BusinessDate = cast( sd.DocumentDate as date )  and  c.LanguageID = 314 
 where  IsEffective = 0 
 AND SD.DocumentID IN (SELECT RIGHT(ID,36) FROM #Report)
 --and   sd.DocumentID = 'E6C51000-630E-45DE-B5C8-1B6550261473'
 group by  
       sd.DocumentID ,sd.DocumentCode,c.date ,sd.DocumentDate
   ,f.ChangeAmountTypeID
   ,DTT.Name
  

 DROP TABLE #Report,#Contract,#price,#ITEM

