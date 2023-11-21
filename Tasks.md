# Environment

Install dbt locally or faster and consistent solution is to use docker: (please, prefer docker for the session)
```shell
docker-compose run -p 8080:8080 dbt
```

# List of tasks


## Create incremental model
References:
- https://docs.getdbt.com/docs/build/incremental-models

Description:
Based on the model `orders` create a new model `orders_incremental` that will basically just copy the table but in incremental mode 
it will only update/insert rows with `updated_at` timestamp newer than latest timestamp in the current `orders_incremental` table.

Checkpoints:
- `orders_incremental` executed and table contains same data as `orders`
  - Check queries in the Activity log
- Update original `orders` table
    ```sql
    UPDATE ORDERS
    SET 
        STATUS='completed',
        UPDATED_AT = TO_TIMESTAMP_NTZ(CURRENT_TIMESTAMP)
    WHERE ORDER_ID=71 AND CUSTOMER_ID = 42;
    ```
- Execute `orders_incremental` again
- Check table contains updated row
- Check Activity log - analyze whole process dbt does for incremental load. What steps dbt does exactly?

## Advanced model selection
References:
- https://docs.getdbt.com/reference/resource-configs/tags
- https://docs.getdbt.com/reference/node-selection/syntax
- https://docs.getdbt.com/reference/commands/list

For testing the selector it's good to use `dbt ls` command so models are not executed. Explore more commands `dbt --help`

1. Select `orders_incremental` and all upstream models
2. Select all upstream staging models for `orders_incremental` only
3. Select all upstream models for `orders_incremental` except staging
4. Select `orders` and downstream models


## Macros #1
References:
- https://docs.getdbt.com/docs/build/jinja-macros
- https://docs.getdbt.com/reference/commands/run-operation


1. Create macro `print_run_timestamp()` that prints run timestamp in UTC
   - Run it via `dbt run-operation print_run_timestamp`
   - Run it inside `orders_incremental` model when it's executed


## Pre&Post hooks
Resources:
- https://docs.getdbt.com/reference/resource-configs/pre-hook-post-hook

1. Run `print_run_timestamp` macro as pre-hook in `orders_incremental` model
   - Try to set it twice as pre-hook. Is it possible?



## Simple logging
Resources:
- https://docs.getdbt.com/reference/resource-configs/pre-hook-post-hook
- https://docs.getdbt.com/reference/dbt-jinja-functions/run_query
- https://docs.getdbt.com/reference/dbt-jinja-functions/modules

We would like to have some visibility into model execution available in a simple table, so we want to create macro
for pre & post hooks that will log timestamp of start and finish model run.

Use this table and create it before you implement the macros.
```sql
CREATE TABLE LOGS (
    model STRING,
    action STRING,
    timestamp TIMESTAMP_NTZ
);
```

Checkpoints:
- Do it for `orders_incremental` model only at the beginning
- Perhaps start with simple print macro to see your macro is called correctly. 
- To get name of the model see https://docs.getdbt.com/reference/dbt-jinja-functions/this
- For timestamp use date module (optionally you can use `run_started_at`)
- Verify runs are logged when running the model
- Optional: Implement it globally for all models (define it just once)

## Macros #2
References:
- https://docs.getdbt.com/reference/dbt-jinja-functions/graph

Graph variable contains basically everything in dbt project - models, tests, seeds, ... It means we can reference anything inside our macros or models.

1. Write a macro that prints model representation (json) with model name as param: `get_model_object('orders')`
Checkpoints:
- Use `graph` variable inside macro
- Check all attributes of the model received from the graph

2. [Optional] Write a macro that will update comments on the columns based on the column descriptions in dbt project
Checkpoints:
- Try it via `on-run-end` [hook](https://docs.getdbt.com/reference/project-configs/on-run-start-on-run-end)
- You can inspect `on-run-end` [context](https://docs.getdbt.com/reference/dbt-jinja-functions/on-run-end-context) as well (but it can be done without it, potentially with previous `get_model_object()` macro)

## Testing `dbt test`

1. Run `dbt test`: check dbt logs and few queries in Activity monitor. Where are those tests defined?
2. Add `orders_incremental` model into [schema](models/schema.yml). Copy/paste from `orders` is enough, but check the definition.
3. Create new test that will check latest `updated_at` max 7 days old
4. Play with constant - make it [configurable](https://docs.getdbt.com/reference/resource-properties/tests))
5. Run only a test you have just implemented


## Packages
"Great expactations" in dbt? Why not ...

1. Add [dbt_expectations](https://hub.getdbt.com/calogica/dbt_expectations/latest/) package into project
2. Play with some expectations

## Docs intermezzo

References:
- https://docs.getdbt.com/reference/commands/cmd-docs

Try out the docs commands and check the web UI (overview, model details, lineage, ...)

`dbt docs generate`
`dbt docs serve`

## Macros #3 - Homework

Create a generic macro for SCD2 tables. The SCD2 models will have just minimal definition like this one:
```sql
{# models/orders_scd2.sql #}
    
{{
    config(
        materialized='incremental',
        unique_key = ['order_id', 'valid_from']
    )
}}

{{ scd2_model(ref('orders')) }}
```

For our orders table the table will contain everything plus `valid_from`, `valid_to` and `is_current` fields

Checkpoints:
- Write & debug the query outside dbt
- Make sure your query is a single query so it fits dbt model, use CTEs (`with` statements)
- Move the query into macro, make sure everything is either configurable or taken from model definition from `graph`
  - Source table
  - PKs
  - List of columns
- Make sure macro works for both full loads and incremental loads
  - Either consider source table as pure increment or filter source table by some timestamp field
