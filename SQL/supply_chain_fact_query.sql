SELECT 
    o.order_id,
    o.order_date,
    o.required_date,
    o.order_status,

    c.customer_name,
    c.city,
    c.state,

    p.product_name,
    p.category,

    w.warehouse_name,

    oi.ordered_qty,

    -- Correct dispatched qty
    LEAST(
        oi.ordered_qty,
        COALESCE(d.dispatched_qty,0)
    ) AS dispatched_qty,

    -- Correct return qty
    COALESCE(r.return_qty,0) AS return_qty,

    -- Correct pending qty
    GREATEST(
        oi.ordered_qty -
        (
            LEAST(
                oi.ordered_qty,
                COALESCE(d.dispatched_qty,0)
            )
            - COALESCE(r.return_qty,0)
        ),
        0
    ) AS pending_qty,

    -- Correct fill rate
    ROUND(
        (
            LEAST(
                oi.ordered_qty,
                COALESCE(d.dispatched_qty,0)
            )
            - COALESCE(r.return_qty,0)
        ) / oi.ordered_qty * 100,
        2
    ) AS fill_rate,

    -- Delay days
    GREATEST(
        DATEDIFF(d.last_dispatch_date, o.required_date),
        0
    ) AS delay_days

FROM orders o

JOIN customers c
ON o.customer_id = c.customer_id

JOIN order_items oi
ON o.order_id = oi.order_id

JOIN products p
ON oi.product_id = p.product_id

-- Dispatch aggregated first
LEFT JOIN
(
    SELECT
        order_item_id,
        warehouse_id,
        SUM(dispatched_qty) AS dispatched_qty,
        MAX(dispatch_date) AS last_dispatch_date
    FROM dispatch
    GROUP BY order_item_id, warehouse_id
) d
ON oi.order_item_id = d.order_item_id

-- Returns aggregated separately
LEFT JOIN
(
    SELECT
        d.order_item_id,
        SUM(r.return_qty) AS return_qty
    FROM returns r
    JOIN dispatch d
    ON r.dispatch_id = d.dispatch_id
    GROUP BY d.order_item_id
) r
ON oi.order_item_id = r.order_item_id

LEFT JOIN warehouses w
ON d.warehouse_id = w.warehouse_id

WHERE o.order_status <> 'Cancelled';
