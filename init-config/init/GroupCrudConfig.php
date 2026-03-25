<?php

declare(strict_types=1);

namespace App\Warmup;

use App\Crudit\Datasource\GroupDatasource;
use Lle\CruditBundle\Contracts\CrudConfigInterface;
use Lle\CruditBundle\Crud\AbstractCrudConfig;
use Lle\CruditBundle\Dto\Field\Field;

class GroupCrudConfig extends AbstractCrudConfig
{
    public function __construct(
        GroupDatasource $datasource,
    ) {
        $this->datasource = $datasource;
    }

    /**
     * @return array<Field|Field[]>
     */
    public function getFields(string $key): array
    {
        $name = Field::new('name');
        $label = Field::new('label');
        $rank = Field::new('rank');
        $active = Field::new('active');

        return match ($key) {
            CrudConfigInterface::INDEX, CrudConfigInterface::SHOW => [
                $name,
                $label,
                $rank,
                $active,
            ],
            default => [],
        };
    }

    public function getRootRoute(): string
    {
        return 'app_crudit_group';
    }
}
