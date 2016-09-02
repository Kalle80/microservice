*** Settings ***
Library     Selenium2Library    10.0  1.0      #timeout, implicit_wait
Library     RequestsLibrary
Library     OperatingSystem
Library     Collections
Library     String

Test Setup  Open Browser And Navigate to Main Page
Suite Setup  Initialize Session
Suite Teardown  Delete All Sessions
#Test Teardown  Close Browser

*** Variables ***
# Execution specific
${BROWSER}                        chrome
${REMOTE_URL}                     ${EMPTY}
${MAIN_URL}
${ORDER_URL}
${CUSTOMER_SERVICE_URL}
${CATALOG_SERVICE_URL}

*** Test Cases ***
Order a product from a catalog
  Given order by "Teemu Selanne" should not exist
    And customer "Teemu Selanne" should not exist
    And product "Torspo" should not be in the catalog
    And product "Torspo" is added to the catalog
    And customer "Teemu Selanne" is added
  When I order product "Torspo"
    And I select customer "Teemu Selanne"
    And I submit the order
  Then I can verify my order

Remove item from catalog
  Given product "Montreal" should not be in the catalog
    And product "Montreal" is added to the catalog
  When I press delete of item "Montreal" in catalog
  Then item "Montreal" is not visible in the catalog

Add item to catalog
  Given item "Bauer" should not be in the catalog
  When I add item "Bauer"
    And I set item price "89" to
    And I submit the item
  Then I can see my item "Bauer" in the catalog

Delete an existing order
  Given order by "Jari Kurri" should not exist
    And customer "Jari Kurri" should not exist
    And product "Koho" should not be in the catalog
    And product "Koho" is ordered by "Jari Kurri"
  When I have an order "Koho" for "Jari Kurri"
    And I press delete button for "Jari Kurri" order
  Then I can verify my order for "Jari Kurri" is deleted

*** Keywords ***
Get JSON Template  [Arguments]  ${form}
  [Documentation]  Reads the json template. Template name is given as an argument.
  ...              Template should reside at the same directory as the test case.
  ${json}=  Get File  ${CURDIR}${/}${form}  encoding=utf-8
  Set Test Variable  ${TEMPLATE}  ${json}

Initialize Session
  [Documentation]  Creates context for REST API calls.
  Set Log Level         TRACE
  ${headers}=  Create Dictionary  Content-type=application/json  Accept=*/*  Accept-language=en-US,en;fi  Cache-control=no-cache
  Set Suite Variable  ${HEADERS}  ${headers}
  Create Session  custsrv  ${CUSTOMER_SERVICE_URL}  headers=${headers}
  Create Session  catalogsrv  ${CATALOG_SERVICE_URL}  headers=${headers}

Open Browser And Navigate to Add Order Page
  [Documentation]
  ${remote}=  Get Variable Value  ${REMOTE_URL}  None
  Run Keyword If  "${remote}"=="None"   Open Browser   ${ORDER_URL}  ${BROWSER}  None
  Run Keyword Unless  "${remote}"=="None"  Open Browser  ${ORDER_URL}  ${BROWSER}  None  ${REMOTE_URL}
  :FOR  ${INDEX}  IN RANGE  1  10
  \  ${passed}=  Run Keyword And Return Status  Wait Until Page Contains  Order : View all  5s
  \  Run Keyword Unless  ${passed}  Reload Page
  \  RUn Keyword If  ${passed}  Exit For Loop
  Click Link  Add Order
  Wait Until Page Contains   Order : Add
  Sleep  2s
  Reload Page

Open Browser And Navigate to Main Page
  [Documentation]
  ${remote}=  Get Variable Value  ${REMOTE_URL}  None
  Run Keyword If  "${remote}"=="None"   Open Browser   ${MAIN_URL}  ${BROWSER}  None
  Run Keyword Unless  "${remote}"=="None"  Open Browser  ${MAIN_URL}  ${BROWSER}  None  ${REMOTE_URL}
  :FOR  ${INDEX}  IN RANGE  1  10
  \  ${passed}=  Run Keyword And Return Status  Wait Until Page Contains  Order Processing  5s
  \  Run Keyword Unless  ${passed}  Reload Page
  \  RUn Keyword If  ${passed}  Exit For Loop
  Sleep  2s
  Reload Page

Product "${name}" is added to the catalog
  Get JSON Template  catalog.json
  Set Test Variable  ${CATALOG_ITEM}  ${name}
  Set Test Variable  ${CATALOG_PRICE}  119.0
  ${data}=  Replace Variables  ${TEMPLATE}
  ${result}=  Post JSON data  catalogsrv  /catalog  ${data}
  Set Test Variable  ${CATALOG_ID}  ${result['id']}
  Log  ${CATALOG_ID}

Customer "${name}" is added
    Get JSON Template  customer.json
    Run Keyword If  "${name}"=="Teemu Selanne"  Add User Teemu Selanne
    Run Keyword If  "${name}"=="Jari Kurri"  Add User Jari Kurri
    ${data}=  Replace Variables  ${TEMPLATE}
    Post JSON data  custsrv  /customer  ${data}

Add User Teemu Selanne
    Set Test Variable  ${NAME}  Selanne
    Set Test Variable  ${FIRSTNAME}  Teemu
    Set Test Variable  ${EMAIL}  teemu.selanne@gmail.com
    Set Test Variable  ${STREET}  Madre Selva LN
    Set Test Variable  ${CITY}  San Diego

Add User Jari Kurri
  Set Test Variable  ${NAME}  Kurri
  Set Test Variable  ${FIRSTNAME}  Jari
  Set Test Variable  ${EMAIL}  jari.kurri@nhl.com
  Set Test Variable  ${STREET}  East Street 1
  Set Test Variable  ${CITY}  New York

Post JSON data  [Arguments]  ${session}  ${uri}  ${data}
  [Documentation]  Posts Customer data through REST API.
  Log  ${data}
  ${resp}=  Post Request  ${session}  ${uri}  data=${data}
  Log  ${resp.text}
  Should Be Equal As Strings  ${resp.status_code}  201
  ${actual}=  To Json  ${resp.content}
  Log  ${actual}
  [Return]  ${actual}

I select customer "${name}"
  Select From List  customerId  ${name}

I order product "${product}"
  wait for navigating to Order Page
  Click Link  Add Order
  Wait Until Page Contains   Order : Add
  Click Button  addLine
  Input Text  orderLine0.count  1
  Select From List  orderLine0.itemId  ${product}

I submit the order
  Click Button  submit
  Wait Until Page Contains  Success

I can verify my order
  wait for navigating to Order Page
  Click Link  xpath=//table/tbody/tr[last()]/td/a
  ${name}=  Get Text  xpath=//div[text()='Customer']/following-sibling::div
  Should Be Equal  ${NAME}  ${name}
  ${price}=  Get Text  xpath=//div[text()='Total price']/following-sibling::div
  Should Be Equal  ${CATALOG_PRICE}  ${price}

product "${catalog_item}" is ordered by "${customer}"
  Given product "${catalog_item}" is added to the catalog
    And customer "${customer}" is added
  When I order product "${catalog_item}"
    And I select customer "${customer}"
    And I submit the order
  Then I can verify my order

I have an order "${catalog_item}" for "${customer}"
  wait for navigating to Order Page
  Wait Until Page Contains  Add Order
  Click Link  xpath=//table/tbody/tr[last()]/td/a
  Wait Until Page Contains  ${customer}
  Wait Until Page Contains  ${catalog_item}

I press delete button for "${customer}" order
  wait for navigating to Order Page
  Wait Until Page Contains  Add Order
  Page Should contain  ${customer}
  Click Element  xpath=//table/tbody/tr[last()]//td[contains(text(),'${customer}')]/..//input[contains(@class,'btn-link')]

I can verify my order for "${customer}" is deleted
  wait for navigating to Order Page
  Wait Until Page Contains  Add Order
  Page Should not contain  ${customer}

I Remove The Catalog Through Service API #not working since no delete implementation in microservice demo
  ${resp}=  Delete Request  catalogsrv  ${CATALOG_SERVICE_URL}/catalog/${CATALOG_ID}
  Should Be Equal As Strings  ${resp.status_code}  204

I press delete of item "${catalog_item}" in catalog
  wait for navigating to Catalog List Page
  Wait Until Page Contains  ${catalog_item}
  Click Element  xpath=//td[contains(text(),'${catalog_item}')]/..//input[contains(@class,'btn-link')]
  Wait Until Page Contains  Success

item "${catalog_item}" is not visible in the catalog
  Wait Until Element Is Not Visible  xpath=//td[contains(text(),'${catalog_item}')]

remove item "${catalog_item}" from catalog
  I press delete of item "${catalog_item}" in catalog
  item "${catalog_item}" is not visible in the catalog

item "${catalog_item}" should not be in the catalog
  wait for navigating to Catalog List Page
  ${passed}=  Run Keyword And Return Status  Page Should Not Contain  ${catalog_item}
  Run Keyword Unless  ${passed}  remove item "${catalog_item}" from catalog

I add item "${catalog_item}"
  wait for navigating to Catalog List Page
  Click Link  Add Item
  Input Text  id=name  ${catalog_item}

I set item price "${price}" to
  Input Text  id=price  ${price}

I submit the item
  Click Button  Submit
  Wait Until Page Contains  Success

I can see my item "${catalog_item}" in the catalog
  wait for navigating to Catalog List Page
  Page Should Contain  ${catalog_item}

I press delete of item "${customer}" in order page
  Click Element  xpath=//td[contains(text(),'${customer}')]/..//input[contains(@class,'btn-link')]
  Wait Until Page Contains  Success

item "${customer}" is not visible in the customer page
  Wait Until Element Is Not Visible  xpath=//td[contains(text(),'${customer}')]

order by "${customer}" should not exist
  wait for navigating to Order Page
  ${passed}=  Run Keyword And Return Status  Page Should Not Contain  ${customer}
  Run Keyword Unless  ${passed}  I press delete of item "${customer}" in order page
  item "${customer}" is not visible in the customer page

product "${catalog_item}" should not be in the catalog
  wait for navigating to Catalog List Page
  ${passed}=  Run Keyword And Return Status  Page Should Not Contain  ${catalog_item}
  Run Keyword Unless  ${passed}  I press delete of item "${catalog_item}" in catalog
  item "${catalog_item}" is not visible in the catalog

I press delete of item in customer page
  [Arguments]  ${first_name}  ${last_name}
  Click Element  xpath=//td[contains(text(),'${first_name}')]/..//td[contains(text(),'${last_name}')]/..//input[contains(@class,'btn-link')]
  Wait Until Page Contains  Success

customer "${customer}" should not exist
  wait for navigating to Customer Page
  @{words}  Split String  ${customer}
  ${first_name}=  Set Variable  @{words}[0]
  ${last_name}=  Set Variable  @{words}[1]
  ${passed}=  Run Keyword And Return Status  Page Should Not Contain  ${last_name}
  Run Keyword Unless  ${passed}  I press delete of item in customer page  ${first_name}  ${last_name}
  item "${last_name}" is not visible in the customer page

navigate To Catalog List Page
  ${catalog_listview_xpath}=  Set Variable  //div[contains(text(),'List / add / remove items')]/..//a[contains(text(),'Catalog')]
  Go To  ${MAIN_URL}
  Wait Until Element Is Visible  xpath=${catalog_listview_xpath}
  Click Element  xpath=${catalog_listview_xpath}
  Wait Until Page Contains  Item : View all

wait for navigating to Catalog List Page
  :FOR  ${INDEX}  IN RANGE  1  10
    \  ${passed}=  Run Keyword And Return Status  navigate To Catalog List Page
    \  Run Keyword Unless  ${passed}  Reload Page
    \  RUn Keyword If  ${passed}  Exit For Loop
    Sleep  2s
    Reload Page

navigate To Order Page
  Go To  ${MAIN_URL}
  Wait Until Page Contains Element  xpath=//a[(text()='Order')]
  Click Link  Order
  Reload Page
  Wait Until Page Contains  Order : View all

wait for navigating to Order Page
  :FOR  ${INDEX}  IN RANGE  1  10
    \  ${passed}=  Run Keyword And Return Status  navigate To Order Page
    \  Run Keyword Unless  ${passed}  Reload Page
    \  RUn Keyword If  ${passed}  Exit For Loop
    Sleep  2s
    Reload Page

navigate To Customer Page
  Go To  ${MAIN_URL}
  Wait Until Page Contains Element  xpath=//a[(text()='Customer')]
  Click Link  Customer
  Reload Page
  Wait Until Page Contains  Customer : View all

wait for navigating to Customer Page
  :FOR  ${INDEX}  IN RANGE  1  10
    \  ${passed}=  Run Keyword And Return Status  navigate To Customer Page
    \  Run Keyword Unless  ${passed}  Reload Page
    \  RUn Keyword If  ${passed}  Exit For Loop
    Sleep  2s
    Reload Page