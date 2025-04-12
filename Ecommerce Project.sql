-- Table Creation--

create table customers (
customer_id varchar(255) primary key,
customer_unique_id varchar(255),
customer_zip_code_prefix int,
customer_city varchar(255),
customer_state varchar(10));

create table geolocation (
geolocation_zip_code_prefix int,
geolocation_lat decimal(10,8),
geolocation_lng decimal(10,8),
geolocation_city varchar(100),
geolocation_state varchar(10));

create table order_item (
order_id varchar(50),
order_item_id int,
product_id varchar(50),
seller_id varchar(50),
shipping_limit_date date,
price decimal(10,2),
freight_value decimal(10,2));

create table payment (
order_id varchar(50),
payment_sequential int,
payment_type varchar(50),
payment_installments int,
payment_value decimal(10,2));

create table sellers (
seller_id varchar(255) primary key,
seller_zip_code_prefix int,
seller_city varchar(255),
seller_state varchar(10));

create table product_category_name_translation (
product_category_name varchar(255) primary key,
product_category_name_english varchar(255));

create table products (
product_id varchar(255) primary key,
product_category_name varchar(255),
product_name_length int,
product_description_length int,
product_photos_qty int,
product_weight_g int,
product_length_cm int,
product_height_cm int,
product_width_cm int);

create table orders (
order_id varchar(255) primary key,
customer_id varchar(255),
order_status varchar(50),
order_purchase_timestamp datetime,
order_approved_at datetime,
order_delivered_carrier_date datetime ,
order_delivered_customer_date datetime ,
order_estimated_delivery_date datetime);

create table order_reviews (
review_id varchar(50) ,
order_id varchar(50),
review_score int,
review_comment_title text,
review_comment_message text,
review_creation_date date,
review_answer_timestamp datetime);


-- Altering the data by creating relationship between the table --

alter table order_reviews
add constraint fk_order_reviews
foreign key (order_id) references orders(order_id);

alter table payment
add constraint fk_payment
foreign key (order_id) references orders(order_id);

alter table order_item
add constraint fk_order_item
foreign key (order_id) references orders(order_id);

alter table order_item
add constraint fk_products
foreign key (product_id) references products(product_id);

alter table order_item
add constraint fk_sellers
foreign key (seller_id) references sellers(seller_id);

alter table orders
add constraint fk_customer
foreign key (customer_id) references customers(customer_id);


insert into product_category_name_translation (product_category_name)
select distinct product_category_name
from products
where product_category_name not in (
    select product_category_name from product_category_name_translation
);
alter table products
add constraint fk_product_category
foreign key (product_category_name) references product_category_name_translation(product_category_name);


create index idx_geolocation_zip on geolocation (geolocation_zip_code_prefix);
insert into geolocation (geolocation_zip_code_prefix, geolocation_lat, geolocation_lng)
select distinct c.customer_zip_code_prefix, 0, 0 
from customers c
left join geolocation g on c.customer_zip_code_prefix = g.geolocation_zip_code_prefix
where g.geolocation_zip_code_prefix is null;
alter table customers
add constraint fk_geolocation
foreign key (customer_zip_code_prefix) 
references geolocation (geolocation_zip_code_prefix);


insert into geolocation (geolocation_zip_code_prefix, geolocation_city, geolocation_state)
select distinct s.seller_zip_code_prefix, s.seller_city, s.seller_state
from sellers s
left join geolocation g on s.seller_zip_code_prefix = g.geolocation_zip_code_prefix
where g.geolocation_zip_code_prefix is null;
alter table sellers 
add constraint fk_sellers_geolocation 
foreign key (seller_zip_code_prefix) 
references geolocation(geolocation_zip_code_prefix);




-- KPI --

-- Weekday Vs Weekend (order_purchase_timestamp) Payment Statistics --

select 
    case 
        when dayofweek(order_purchase_timestamp) in (1, 7) then 'weekend'
        else 'weekday'
    end as day_type,
count(distinct orders.order_id) as total_orders,
round(count(*) * 100.0 / sum(count(*)) over(), 2) as percentage
from orders
join payment on
orders.order_id=payment.order_id
group by day_type;



-- Number of Orders with review score 5 and payment type as credit card --

select count(distinct orders.order_id) as total_orders from orders 
join order_reviews on 
orders.order_id=order_reviews.order_id
join payment on
order_reviews.order_id=payment.order_id
where order_reviews.review_score = '5'
and payment.payment_type = 'credit_card';



-- Average number of days taken for order_delivered_customer_date for pet_shop --

alter table orders add column total_days_to_deliver int;
update orders 
set total_days_to_deliver = datediff(order_delivered_customer_date, order_purchase_timestamp);

select round(avg(orders.total_days_to_deliver),0) as avg_days_of_delivery,
product_category_name_translation.product_category_name_english as category_name from orders
join order_item on
orders.order_id=order_item.order_id
join products on
order_item.product_id=products.product_id
join product_category_name_translation on
products.product_category_name=product_category_name_translation.product_category_name
where product_category_name_translation.product_category_name_english = 'pet_shop';



-- Average price and payment values from customers of sao paulo city --

select round(avg(order_item.price),0) as avg_price from order_item
join orders on
orders.order_id=order_item.order_id
join customers on 
orders.customer_id=customers.customer_id
where customers.customer_city='sao paulo';

select round(avg(payment.payment_value),0) as avg_payment_value from payment
join orders on
orders.order_id=payment.order_id
join customers on 
orders.customer_id=customers.customer_id
where customers.customer_city='sao paulo';



-- Relationship between shipping days (order_delivered_customer_date - order_purchase_timestamp) Vs review scores --

select order_reviews.review_score as review_score,
round(avg(orders.total_days_to_deliver),0) as avg_shipping_day
from orders 
join order_reviews on
orders.order_id=order_reviews.order_id
group by review_score
order by review_score ;


